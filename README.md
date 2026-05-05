# Node.js Express App

A simple Node.js Express application with a `/health` endpoint, Docker support, and automated CI/CD using GitHub Actions. This project is beginner-friendly and designed for easy deployment and rollback.

---

## Features

- **Express server** running on **port 3000**
- `/health` endpoint for health checks
- **Dockerized** for containerized deployment
- **GitHub Actions** for CI/CD, including deployment and rollback workflows

---

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v14 or later)
- [npm](https://www.npmjs.com/)
- [Docker](https://www.docker.com/) (optional, for containerization)
- [Git](https://git-scm.com/)

---

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/your-repo.git
   cd your-repo
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

---

## Running Locally

Start the server with:

```bash
npm start
```

The app will be available at [http://localhost:3000](http://localhost:3000).

Test the health endpoint:

```bash
curl http://localhost:3000/health
```

---

## Running with Docker

1. **Build the Docker image:**
   ```bash
   docker build -t node-express-app .
   ```

2. **Run the container:**
   ```bash
   docker run -p 3000:3000 node-express-app
   ```

The app will be accessible at [http://localhost:3000](http://localhost:3000).

---

## CI/CD with GitHub Actions

This project uses **GitHub Actions** for continuous integration and deployment:

- **CI Workflow:** Runs on every push and pull request. It installs dependencies, runs tests, and builds the Docker image.
- **Deployment Workflow:** Deploys the app automatically when changes are pushed to the main branch.
- **Rollback Workflow:** Allows rolling back to a previous deployment if needed.

All workflows are defined in the `.github/workflows/` directory.

---

## Project Structure

```
.
├── Dockerfile
├── devops.sh
├── index.js
├── package.json
├── tests/
│   └── health.test.js
└── .github/
    └── workflows/
        ├── ci.yml
        ├── deploy.yml
        └── rollback.yml
```

---

## Contributing

Contributions are welcome! Please open issues or pull requests for improvements.

---

## License

This project is licensed under the MIT License.
