# Use a recommended Jenkins LTS base image with OpenJDK 17 for broader compatibility
FROM jenkins/jenkins:lts-jdk17

# Switch to root user to install packages
USER root

# Install necessary tools for plugins (e.g., git, curl, openssh-client)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    openssh-client \
    apt-transport-https \
    ca-certificates \
    gnupg \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK for gcloud commands within Jenkins jobs
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && \
    apt-get install -y google-cloud-sdk

# Switch back to the jenkins user
USER jenkins

# Define Jenkins home directory
ENV JENKINS_HOME /var/jenkins_home

# Create a directory for JCasC configurations inside the Jenkins home
RUN mkdir -p ${JENKINS_HOME}/casc_configs

# Copy your JCasC YAML file(s) into the image
COPY --chown=jenkins:jenkins jenkins.yaml ${JENKINS_HOME}/casc_configs/

# Set the environment variable to tell Jenkins where to find the JCasC files
ENV CASC_JENKINS_CONFIG=${JENKINS_HOME}/casc_configs/jenkins.yaml

# Disable the Jenkins setup wizard, as JCasC will configure Jenkins
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.DNSMultiCast.disabled=true"

# Expose Jenkins ports
EXPOSE 8080
EXPOSE 50000
