#!/usr/bin/groovy

@Library(['github.com/indigo-dc/jenkins-pipeline-library@1.2.3']) _

pipeline {
    agent {
        label 'docker-build'
    }

    environment {
        dockerhub_repo = "deephdc/deep-oc-benchmarks_cnn"
        base_image = "nvcr.io/nvidia/tensorflow"
        base_tag = "20.06-tf2-py3"  // valid for both CPU and GPU use.
        // Other combinations        
        //base_image = "tensorflow/tensorflow"
        //base_tag = "1.14.0-gpu-py3"
        // NVIDIA ngc repository images
        //base_image = "nvcr.io/nvidia/tensorflow"
        //base_tag = "20.06-tf2-py3"
    }

    stages {
        stage('Validate metadata') {
            steps {
                checkout scm
                sh 'deep-app-schema-validator metadata.json'
            }
        }
        stage('Docker image building') {
            when {
                anyOf {
                   branch 'master'
                   branch 'test'
                   buildingTag()
               }
            }
            steps{
                 dir('check_oc_artifact'){
                    // clone checking scripts
                    git url: 'https://github.com/deephdc/deep-check_oc_artifact'
                }
                dir('deep-oc-user_app'){
                    checkout scm
                    script {
                        // build different tags
                        id = "${env.dockerhub_repo}"

                        if (env.BRANCH_NAME == 'master') {
                            // tag benchmark types
                            tag_benchmark = ['latest', 'benchmark', 'cpu', 'gpu']
                            tag_to_check = 'latest'
                            tag_pro = ['pro']
                        }
                        if (env.BRANCH_NAME == 'test') {
                            // tag benchmark types
                            // !!use double quotes, single quotes do not evaluate strings!!
                            tag_benchmark = ["${env.BRANCH_NAME}", "benchmark-${env.BRANCH_NAME}"]
                            tag_to_check = "${env.BRANCH_NAME}"
                            tag_pro = ["pro-${env.BRANCH_NAME}"]
                        }

                        id_bench = DockerBuild(id,
                                            tag: tag_benchmark, 
                                            build_args: ["image=${env.base_image}",
                                                         "tag=${env.base_tag}",
                                                         "btype=benchmark",
                                                         "branch=${env.BRANCH_NAME}",
                                                         "jlab=true"])
                        // Check that the image starts and get_metadata responses correctly
                        sh "bash ../check_oc_artifact/check_artifact.sh ${env.dockerhub_repo}:${tag_to_check}"

                        // 'pro' type
                        id_pro = DockerBuild(id,
                                            tag: tag_pro, 
                                            build_args: ["image=${env.base_image}",
                                                         "tag=${env.base_tag}",
                                                         "btype=pro",
                                                         "branch=${env.BRANCH_NAME}",
                                                         "jlab=true"])
                    }
                }
            }
            post {
                failure {
                    DockerClean()
                }
            }
        }


        stage('Docker Hub delivery') {
            when {
                anyOf {
                   branch 'master'
                   branch 'test'
                   buildingTag()
               }
            }
            steps{
                script {
                    DockerPush(id_bench)
                    DockerPush(id_pro)
                }
            }
            post {
                failure {
                    DockerClean()
                }
                always {
                    cleanWs()
                }
            }
        }

        stage("Render metadata on the marketplace") {
            when {
                allOf {
                    branch 'master'
                    changeset 'metadata.json'
                }
            }
            steps {
                script {
                    def job_result = JenkinsBuildJob("Pipeline-as-code/deephdc.github.io/pelican")
                    job_result_url = job_result.absoluteUrl
                }
            }
        }
    }
}
