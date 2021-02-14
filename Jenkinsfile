#!/usr/bin/groovy

@Library(['github.com/indigo-dc/jenkins-pipeline-library@1.2.3']) _

pipeline {
    agent {
        label 'docker-build'
    }

    environment {
        dockerhub_repo = "deephdc/deep-oc-benchmarks_cnn"
        base_image = "tensorflow/tensorflow"
        // base_image = "deephdc/tensorflow"
        // it seems 'gpu' versions also work on CPU. Use only 'gpu'.
        base_tag = "1.14.0-gpu-py3"
        // NVIDIA ngc repository images
        base_nv_image = "nvcr.io/nvidia/tensorflow"
        base_nv_tag = "20.06-tf2-py3"
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
                            // tag flavors
                            tag_synthetic = ['latest', 'synthetic']
                            tag_dataset = ['dataset']
                            tag_pro = ['pro']
                        }
                        if (env.BRANCH_NAME == 'test') {
                            // tag flavors
                            // !!use double quotes, single quotes do not evaluate strings!!
                            tag_synthetic = ["${env.BRANCH_NAME}", "synthetic-${env.BRANCH_NAME}"]
                            tag_dataset = ["dataset-${env.BRANCH_NAME}"]
                            tag_pro = ["pro-${env.BRANCH_NAME}"]
                        }

                        id_synth = DockerBuild(id,
                                            tag: tag_synthetic, 
                                            build_args: ["image=${env.base_image}",
                                                         "tag=${env.base_tag}",
                                                         "flavor=synthetic",
                                                         "branch=${env.BRANCH_NAME}",
                                                         "jlab=true"])
                        // Check that the image starts and get_metadata responses correctly
                        sh "bash ../check_oc_artifact/check_artifact.sh ${env.dockerhub_repo}"

                        // 'dataset' flavor
                        id_data = DockerBuild(id,
                                            tag: tag_dataset, 
                                            build_args: ["image=${env.base_image}",
                                                         "tag=${env.base_tag}",
                                                         "flavor=dataset",
                                                         "branch=${env.BRANCH_NAME}",
                                                         "jlab=true"])
                        // 'pro' flavor
                        id_pro = DockerBuild(id,
                                            tag: tag_pro, 
                                            build_args: ["image=${env.base_image}",
                                                         "tag=${env.base_tag}",
                                                         "flavor=pro",
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
                    DockerPush(id_synth)
                    DockerPush(id_data)
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
