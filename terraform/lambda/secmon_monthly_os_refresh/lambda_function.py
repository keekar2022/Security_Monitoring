# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
"""Monthly OS refresh: Thursday after Patch Tuesday (2nd Tuesday + 2 days)."""

from __future__ import annotations

import json
import os
from datetime import date, timedelta

import boto3


def _second_tuesday(year: int, month: int) -> date:
    d = date(year, month, 1)
    tuesdays: list[date] = []
    while d.month == month:
        if d.weekday() == 1:
            tuesdays.append(d)
        d += timedelta(days=1)
    return tuesdays[1]


def _refresh_day(year: int, month: int) -> date:
    return _second_tuesday(year, month) + timedelta(days=2)


def _latest_ami(ec2, owner: str, pattern: str, arch: str) -> str:
    resp = ec2.describe_images(
        Owners=[owner],
        Filters=[
            {"Name": "name", "Values": [pattern]},
            {"Name": "state", "Values": ["available"]},
            {"Name": "architecture", "Values": [arch]},
            {"Name": "virtualization-type", "Values": ["hvm"]},
            {"Name": "root-device-type", "Values": ["ebs"]},
        ],
    )
    images = sorted(resp.get("Images", []), key=lambda i: i["CreationDate"], reverse=True)
    if not images:
        raise RuntimeError(f"No AMI found for owner={owner} pattern={pattern}")
    return images[0]["ImageId"]


def handler(event, context):  # noqa: ANN001, ARG001
    today = date.today()
    force = str(event.get("force", "")).lower() in ("1", "true", "yes")
    target = _refresh_day(today.year, today.month)

    if not force and today != target:
        msg = f"Skip: today {today} is not refresh day {target}"
        print(msg)
        return {"status": "skipped", "message": msg}

    lt_name = os.environ["LAUNCH_TEMPLATE_NAME"]
    asg_name = os.environ["ASG_NAME"]
    owner = os.environ["IMAGE_FACTORY_OWNER_ID"]
    pattern = os.environ.get("IMAGE_FACTORY_AMI_PATTERN", "*Amazon*Linux*2023*EMR*")
    arch = os.environ.get("INSTANCE_ARCHITECTURE", "x86_64")
    scale_out = os.environ.get("OS_REFRESH_SCALE_OUT", "true").lower() == "true"
    max_size = int(os.environ.get("ASG_MAX_SIZE", "2"))

    ec2 = boto3.client("ec2")
    asg = boto3.client("autoscaling")

    ami_id = os.environ.get("OVERRIDE_AMI_ID") or _latest_ami(ec2, owner, pattern, arch)
    print(f"Using AMI {ami_id}")

    lt = ec2.describe_launch_templates(LaunchTemplateNames=[lt_name])["LaunchTemplates"][0]
    lt_id = lt["LaunchTemplateId"]

    new_ver = ec2.create_launch_template_version(
        LaunchTemplateId=lt_id,
        SourceVersion="$Latest",
        LaunchTemplateData={"ImageId": ami_id},
    )["LaunchTemplateVersion"]["VersionNumber"]
    ec2.modify_launch_template(
        LaunchTemplateId=lt_id,
        DefaultVersion=str(new_ver),
    )
    print(f"Launch template {lt_name} default version -> {new_ver}")

    if scale_out and max_size > 1:
        asg.update_auto_scaling_group(
            AutoScalingGroupName=asg_name,
            DesiredCapacity=max_size,
        )
        print(f"Scaled ASG {asg_name} desired capacity to {max_size}")

    refresh = asg.start_instance_refresh(
        AutoScalingGroupName=asg_name,
        Strategy="Rolling",
        Preferences={
            "MinHealthyPercentage": 50,
            "InstanceWarmup": int(os.environ.get("INSTANCE_WARMUP", "420")),
        },
    )
    refresh_id = refresh["InstanceRefreshId"]
    print(f"Started instance refresh {refresh_id}")

    return {
        "status": "started",
        "ami_id": ami_id,
        "launch_template_version": new_ver,
        "instance_refresh_id": refresh_id,
        "refresh_day": str(target),
    }
