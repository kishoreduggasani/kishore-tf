pipeline {
    agent any
    tools {terraform "terraform"}
    
    stages {
        stage('clone code') {
            steps {
               git branch: 'main', url: 'https://github.com/kishoreduggasani/kishore-tf.git' 
            }
        }
        stage('check the code') {
            steps {
               sh '''
               pwd
               ls -l
               terraform --version
               terraform init
               terraform plan
               terraform destroy --auto-approve
               '''
            }
        }
    }
}
