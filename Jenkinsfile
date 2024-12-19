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
        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t $DOCKER_IMAGE .'
                }
            }
        }
        stage('Run Container') {
            steps {
                script {
                    sh '''
                    docker run -d --name $DOCKER_CONTAINER $DOCKER_IMAGE
                    docker ps | grep $DOCKER_CONTAINER
                    '''
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
            mail to: 'mark.tabatskyi@gmail.com',
                 subject: "Build #${env.BUILD_NUMBER} Successful",
                 body: "The job completed successfully. Check Jenkins for details."
        }
        failure {
            mail to: 'mark.tabatskyi@gmail.com',
                 subject: "Build #${env.BUILD_NUMBER} Failed",
                 body: "The job failed. Check Jenkins for details."
        }
    }
}
