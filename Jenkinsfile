pipeline {
    agent any
    environment {
        DOCKER_IMAGE = "tabatskyi/silly_demo:${env.BUILD_NUMBER}"
        DOCKER_CONTAINER = "silly-demo"
    }
    stages {
        stage('Fetch changes') {
            steps {
                git branch: 'main', url: 'https://github.com/Tabatskyi/golang-demo.git'
            }
        }
        stage('Build and run Docker Image') {
            steps {
                script {
                    sh 'docker compose build && docker compose up && docker ps | grep $DOCKER_CONTAINER'
                }
            }
        }
    }
    post {
        always {
            script {
                try {
                    def result = sh(script: "docker inspect --format='{{.State.Running}}' $DOCKER_CONTAINER", returnStdout: true).trim()
                    if (result != 'true') {
                        error("Container failed to start.")
                    }
                } catch (Exception e) {
                    echo "Error while verifying container status: ${e.message}"
                }
            }
        }
        success {
            script {
                echo "Container is running successfully."
            }
            mail to: 'mark.tabatskyi@gmail.com',
                 subject: "Build #${env.BUILD_NUMBER} Successful",
                 body: "The job completed successfully. Check Jenkins for details."
        }
        failure {
            script {
                def logs = sh(script: "docker logs $DOCKER_CONTAINER", returnStdout: true).trim()
                echo "Container is not running. Logs: ${logs}"
            }
            mail to: 'mark.tabatskyi@gmail.com',
                 subject: "Build #${env.BUILD_NUMBER} Failed",
                 body: "The job failed. Check Jenkins for details."
        }
    }
}
