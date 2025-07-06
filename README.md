# 📸 Serverless Photo-Uploader on AWS

Upload JPG/PNG images via a Flask frontend → S3.  
S3 **event notifications** trigger a Lambda function that:
```
    1. Generates a 256×256 thumbnail with Pillow (PIL).
    2. Stores image metadata (key, size, upload time, thumbnail path) in DynamoDB.

Everything is reproducible with **Terraform**, no click-ops required.

## ✨ Features
```
    - Flask uploader with presigned‐URL–free direct upload  
    - Public S3 bucket (great for demos)  
    - Event-driven Lambda (Python 3.11)  
    - DynamoDB pay-per-request table  
    - Thumbnails stored alongside originals  
    - IaC: one `terraform apply` and you’re done

## 🖇️ Architecture
[ Flask UI ] ──► [ S3 bucket ] ──► (Event) ──► [ Lambda ] ─► [ DynamoDB ]
└──── uploads thumbnails back to S3 ──┘

🛠️ Tech stack

| Layer    | Service / Tool            |
| -------- | ------------------------- |
| Frontend | Flask, Bootstrap          |
| Storage  | Amazon S3 (public bucket) |
| Compute  | AWS Lambda (Python 3.11)  |
| DB       | Amazon DynamoDB           |
| IaC      | Terraform 1.6             |
