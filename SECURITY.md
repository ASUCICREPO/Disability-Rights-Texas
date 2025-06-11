# Security Policy

## Environment Variables

This project uses environment variables to store sensitive configuration. Never commit `.env` files to the repository.

1. Copy `.env.example` to `.env` and fill in your actual values
2. Make sure `.env` is in your `.gitignore` file

## API Keys and Credentials

- Never hardcode API keys, tokens, or credentials in your code
- Use environment variables for all sensitive information
- Rotate API keys regularly
- Use the principle of least privilege when creating API keys

## AWS Security Best Practices

When deploying to AWS:

1. Use IAM roles with minimal permissions
2. Enable CloudTrail logging
3. Configure proper CORS settings for API Gateway
4. Use AWS Secrets Manager for sensitive credentials
5. Enable encryption at rest for all data stores
6. Use HTTPS for all API endpoints

## Reporting Security Issues

If you discover a security vulnerability, please send an email to [security@example.com](mailto:security@example.com). Do not create public GitHub issues for security vulnerabilities.

## Code Reviews

All code changes should be reviewed for security issues before merging, with particular attention to:

- Input validation
- Authentication and authorization
- Data encryption
- Dependency vulnerabilities
- API security