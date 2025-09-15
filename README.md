# ADK Agents Golden

This repository provides a development environment and tools for working with Google ADK agents and related projects.

## Project Overview
This project sets up a Python development environment, clones Google ADK repositories, and installs required dependencies for agent development and experimentation.

## Getting Started

1.  Open this repository in a GitHub Codespace.
2.  The dev container will be built automatically, and the `post-create.py` script will set up the virtual environment and clone the required repositories.
3.  Once the Codespace is ready, you can start working with the ADK. The terminal will automatically use the Python virtual environment.

## Project Structure

*   `adk.json`: Configuration file for the ADK.
*   `agents/`: Directory containing the agent code.
*   `requirements.txt`: Python dependencies for the project.
*   `.devcontainer/`: Contains the dev container configuration.
    *   `devcontainer.json`: The primary configuration file for the dev container.
    *   `post-create.py`: A Python script that runs after the container is created to set up the environment.

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
See individual ADK repositories for their respective licenses.