// Concept: Mukesh Kesharwani
// Contact: mukesh.kesharwani@adobe.com
//
// Upload metrics data directory to S3 (EC2 instance profile credentials).
package s3publish

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// Publish syncs dataDir to s3://bucket/prefix/ (upload only; uses filepath.Walk).
func Publish(ctx context.Context, dataDir, bucket, prefix string) error {
	dataDir = filepath.Clean(dataDir)
	prefix = strings.Trim(prefix, "/")
	if prefix != "" {
		prefix += "/"
	}

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("aws config: %w", err)
	}
	client := s3.NewFromConfig(cfg)

	var uploaded int
	err = filepath.Walk(dataDir, func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if info.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(dataDir, path)
		if err != nil {
			return err
		}
		key := prefix + filepath.ToSlash(rel)
		f, err := os.Open(path)
		if err != nil {
			return err
		}
		defer f.Close()

		_, err = client.PutObject(ctx, &s3.PutObjectInput{
			Bucket: aws.String(bucket),
			Key:    aws.String(key),
			Body:   f,
		})
		if err != nil {
			return fmt.Errorf("put s3://%s/%s: %w", bucket, key, err)
		}
		uploaded++
		return nil
	})
	if err != nil {
		return err
	}

	slog.Info("S3 publish complete",
		"service.name", "secmon-collector",
		"operation", "s3_publish",
		"s3.bucket", bucket,
		"s3.prefix", prefix,
		"files.uploaded", uploaded,
	)
	return nil
}
