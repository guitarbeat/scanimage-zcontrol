# Security Policy

## Supported Versions

We actively support the following versions of ScanImage Z-Control:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| dev     | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability, please follow these guidelines:

### How to Report

1. **Do NOT** create a public GitHub issue for security vulnerabilities
2. Send an email to the project maintainers with details about the vulnerability
3. Include as much information as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if known)

### What to Expect

- **Initial Response**: We will acknowledge receipt of your vulnerability report within 48 hours
- **Investigation**: We will investigate and validate the reported vulnerability
- **Resolution Timeline**: 
  - Critical vulnerabilities: Within 7 days
  - High severity: Within 30 days
  - Medium/Low severity: Within 90 days
- **Communication**: We will keep you informed of our progress throughout the process

### Responsible Disclosure

We practice responsible disclosure:
- We will work with you to understand and resolve the issue
- We will credit you for the discovery (unless you prefer to remain anonymous)
- We ask that you do not publicly disclose the vulnerability until we have had a chance to address it

## Security Considerations

### MATLAB Environment
- This application runs in MATLAB and has access to system resources
- Be cautious when running code from untrusted sources
- Ensure MATLAB installation is up to date with security patches

### Hardware Integration
- The application interfaces with microscopy hardware
- Ensure hardware drivers are from trusted sources
- Network connections to ScanImage should be on trusted/isolated networks

### Configuration Files
- Configuration files may contain sensitive information
- Ensure proper file permissions on configuration directories
- Do not commit sensitive configuration data to version control

### MEX Files
- MEX files provide native code integration
- Ensure MEX files are compiled from trusted sources
- Verify checksums of distributed MEX files

## Best Practices for Users

1. **Keep Software Updated**: Regularly update MATLAB and the application
2. **Network Security**: Use firewalls and isolated networks for hardware control
3. **Access Control**: Limit file system permissions appropriately
4. **Backup Security**: Secure backups and configuration files
5. **Audit Trail**: Monitor application logs for unusual activity

## Security Features

- Input validation for configuration files
- Error handling to prevent information disclosure
- Resource cleanup to prevent resource exhaustion
- Path validation to prevent directory traversal

## Known Security Considerations

- MATLAB applications have inherent access to the file system
- Hardware control applications require elevated privileges
- Network communication with ScanImage is unencrypted (limitation of ScanImage)

## Contact Information

For security-related inquiries or to report vulnerabilities:
- Create a private issue on GitHub (if repository settings allow)
- Contact project maintainers through GitHub
- Check the README.md for current contact information

Thank you for helping keep ScanImage Z-Control secure!