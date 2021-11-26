# Volgnie

## Requirements
1. Node.js 14 or higher
2. Ruby 2.7 
3. Redis. An easy way to run Redis locally (via Docker):
   ```bash
    # on Windows
    docker run --name redis -d -p 6379:6379 -v $env:DockerVolumes/redis/data:/data redis redis-server --appendonly yes
   ```

## Setup
- Install dependencies:
  ```bash
  npm ci --production=false
  bundle install
  ```

To run the app locally:

```bash
npm run offline
```