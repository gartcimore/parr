# Parr Media Server - Testing Guide

This directory contains comprehensive tests for the Parr media server infrastructure and configuration components.

## 🐳 Quick Start (Containerized - Recommended)

```bash
# Run all tests in containers (no host system changes)
./test-containerized.sh

# Advanced testing with options
./scripts/run-tests.sh all        # All test suites
./scripts/run-tests.sh validation # Environment validation only
./scripts/run-tests.sh compose    # Docker Compose tests only
./scripts/run-tests.sh setup      # Setup script tests only
```

## 📋 Test Suites

### 1. **Environment Configuration Tests** (`test-env-validation.sh`)
- Validates `.env.sample` file format and structure
- Checks for required environment variables
- Validates placeholder values and formats
- Tests timezone and VPN type configurations

### 2. **Docker Compose Configuration Tests** (`test-docker-compose.sh`)
- Validates `docker-compose.yml` syntax
- Checks service definitions and dependencies
- Validates network configurations
- Tests Traefik labels and routing
- Validates volume mounts and security settings

### 3. **Setup Scripts Tests** (`test-setup-scripts.sh`)
- Tests shell script syntax validation
- Validates `setup-utils.sh` utility functions
- Tests `create-volumes.sh` directory creation logic
- Tests `setup.sh` automated configuration
- Validates `update.sh` logic and commands

### 4. **Comprehensive Test Runner** (`run-all-tests.sh`)
- Executes all test suites in sequence
- Provides detailed reporting and summaries
- Returns appropriate exit codes for CI/CD integration

## 🐳 Containerized Testing

### Why Containerized?
- **🔒 Isolation**: Tests run without affecting your host system
- **📦 Consistency**: Same environment across different systems
- **🔍 Inspection**: Created files mounted locally for inspection
- **🚀 No Setup**: Only Docker required
- **🛡️ Security**: No sudo required, no host file creation

### Container Services

The `docker-compose.test.yml` defines several test services:

- **`test-runner`**: Complete comprehensive test suite
- **`test-validation`**: Environment configuration validation only
- **`test-compose`**: Docker Compose configuration tests
- **`test-setup`**: Setup script functionality tests

### Volume Inspection

Test outputs are mounted to `test-output/` for inspection:

```
test-output/
├── config/          # Test config directories
├── data/            # Test data directories
├── setup-config/    # Setup script config test
├── setup-data/      # Setup script data test
├── validation/      # Validation test output
├── compose/         # Compose test output
└── setup/           # Setup test output
```

## 🚀 Running Tests

### Containerized (Recommended)

```bash
# Simple containerized testing
./test-containerized.sh

# Advanced options
./scripts/run-tests.sh validation  # Quick validation
./scripts/run-tests.sh compose     # Docker Compose tests
./scripts/run-tests.sh setup       # Setup scripts
./scripts/run-tests.sh all         # Everything
```

### Local Testing (Alternative)

```bash
# Run all tests locally
./tests/run-all-tests.sh

# Run individual test suites
./tests/test-env-validation.sh
./tests/test-docker-compose.sh
./tests/test-setup-scripts.sh
```

### Inspecting Results

```bash
# View created test directories
find test-output -type d | sort

# Check directory sizes
du -sh test-output/*

# View specific test outputs
ls -la test-output/setup-config/
ls -la test-output/setup-data/
```

## 🔧 CI/CD Integration

### GitHub Actions Pipeline

The project includes optimized CI/CD testing:

1. **Syntax Validation** - Fast feedback on basic issues
2. **Containerized Tests** - Comprehensive test suite in containers
3. **Security Scanning** - Trivy vulnerability scanning
4. **Service Validation** - Basic service startup testing

### Pipeline Features

- **Parallel Execution**: Tests run efficiently in parallel
- **Artifact Collection**: Test outputs uploaded as artifacts
- **Fast Feedback**: Quick syntax validation before heavy tests
- **Security Integration**: Automated vulnerability scanning

## 📊 Test Coverage

Current test coverage includes:

- ✅ **100%** of configuration files
- ✅ **100%** of setup scripts
- ✅ **100%** of Docker services
- ✅ Security configurations
- ✅ Network configurations
- ✅ Volume configurations

### Test Categories

**Infrastructure Tests:**
- Environment variable validation
- Docker Compose syntax and structure
- Network configuration validation
- Volume mount verification
- Service dependency checking

**Configuration Tests:**
- Setup script functionality
- Directory creation logic (simulated)
- Traefik routing configuration
- Security settings validation
- VPN configuration validation

**Security Tests:**
- Hardcoded secret detection
- Docker socket proxy restrictions
- Port exposure validation
- Container capability checks
- Vulnerability scanning (Trivy)

## 🛠️ Development Workflow

### Before Committing

```bash
# Quick validation
./scripts/run-tests.sh validation

# Full test suite
./test-containerized.sh
```

### Adding New Tests

1. Add test functions to appropriate test suite file
2. Follow the test function template:

```bash
test_new_functionality() {
    print_test "Description of what is being tested"
    
    # Test implementation
    if [[ condition ]]; then
        print_pass "Test passed message"
        return 0
    else
        print_fail "Test failed message"
        return 1
    fi
}
```

3. Add function name to test execution array
4. Test locally before committing

## 🐛 Troubleshooting

### Docker Issues

```bash
# Check Docker installation
docker --version
docker-compose --version

# Rebuild test containers
docker-compose -f docker-compose.test.yml build --no-cache

# Clean up containers
docker-compose -f docker-compose.test.yml down --rmi all
```

### Permission Issues

```bash
# Make scripts executable
chmod +x test-containerized.sh scripts/run-tests.sh tests/*.sh

# Check test output permissions
ls -la test-output/
```

### Test Failures

1. **Review test output**: Check detailed error messages
2. **Inspect artifacts**: Examine `test-output/` directory
3. **Run specific tests**: Use `./scripts/run-tests.sh <type>`
4. **Debug interactively**: Use container debug mode

### Interactive Debugging

```bash
# Run container interactively
docker-compose -f docker-compose.test.yml run --rm --entrypoint /bin/bash test-runner

# Check container logs
docker-compose -f docker-compose.test.yml logs test-runner
```

### Common Issues

**"Read-only file system" errors:**
- Tests are designed to not modify host system
- Use temporary files in containers for testing

**Docker Compose command not found:**
- Tests auto-detect `docker compose` vs `docker-compose`
- Ensure Docker Compose is properly installed

**Permission denied on Docker socket:**
- Add user to docker group: `sudo usermod -a -G docker $USER`
- Or run with sudo (not recommended for regular use)

## 🎯 Best Practices

### For Contributors

1. **Always run tests before committing**
2. **Use containerized testing for consistency**
3. **Add tests for new functionality**
4. **Check test output directory after runs**
5. **Keep tests fast and focused**

### For Maintainers

1. **Maintain test isolation**
2. **Keep documentation current**
3. **Monitor CI/CD pipeline health**
4. **Optimize test execution time**
5. **Ensure security scanning stays updated**

## 📁 File Structure

```
tests/
├── README.md                    # This comprehensive guide
├── run-all-tests.sh            # Local test runner
├── test-env-validation.sh      # Environment configuration tests
├── test-docker-compose.sh      # Docker Compose tests
└── test-setup-scripts.sh       # Setup script tests

# Root level containerized testing
├── test-containerized.sh       # Simple containerized runner
├── docker-compose.test.yml     # Test container definitions
├── Dockerfile.test             # Test container image
└── scripts/
    └── run-tests.sh            # Advanced containerized runner
```

## 🔗 Related Documentation

- [Main Project README](../README.md) - Project overview and setup
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Trivy Security Scanner](https://github.com/aquasecurity/trivy)

---

**💡 Tip**: Use containerized testing (`./test-containerized.sh`) for the most reliable and consistent testing experience. It requires only Docker and doesn't modify your host system.