<div align="center">
<img src="https://marketplace.deep-hybrid-datacloud.eu/images/logo-deep.png" alt="logo" width="300"/>
</div>

# DEEP-OC-benchmarks_cnn

[![Build Status](https://jenkins.indigo-datacloud.eu/buildStatus/icon?job=Pipeline-as-code/DEEP-OC-org/DEEP-OC-benchmarks_cnn/master)](https://jenkins.indigo-datacloud.eu/job/Pipeline-as-code/job/DEEP-OC-org/job/DEEP-OC-benchmarks_cnn/job/master)

This is a container that will run the DEEP as a Service API component, [DEEPaaS API](https://github.com/indigo-dc/DEEPaaS), with [tf_cnn_benchmarks](https://github.com/tensorflow/benchmarks/tree/master/scripts/tf_cnn_benchmarks) from the TensorFlow team. The source code for integration of [tf_cnn_benchmarks](https://github.com/tensorflow/benchmarks/tree/master/scripts/tf_cnn_benchmarks) with [DEEPaaS API](https://github.com/indigo-dc/DEEPaaS) is located in [benchmarks_cnn_api](https://github.com/deephdc/benchmarks_cnn_api).

The application has several 'flavors' implemented:

 * 'synthetic': generated in-memory data mimicking ImageNet dataset, avoids storage I/O
 * 'dataset': ca. 5GB subset of real ImageNet data is used (downloaded automatically but may take time!), therefore involves I/O. Useful in comparison with 'synthetic' flavor.
 * 'pro': possible to customize various inputs: neural network, batch_size, dataset, etc

'synthetic' and 'dataset' have as an input the number of GPUs only, the rest is defined inside the application: 
Both flavors run sequentially 100 batches of googlenet, inception3, resnet50, vgg16 and sum 'average_examples_per_sec' to derive the final 'score'.
The optimizer is set to 'sgd'. The batch size is defined per GPU and scaled with the GPU memory. Initial batch_sizes are set for 4GB GPU memory as: 

 * googlenet: 96
 * inception3: 24
 * resnet50: 24
 * vgg16: 16

It is also possible to run both flavors on CPU but the batch_size is fixed to 16 for all neural networks independent of the memory available.


## Running the container

### Directly from Docker Hub

To run the Docker container directly from Docker Hub and start using the API
simply run the following command:

```bash
$ docker run -ti -p 5000:5000 -p 6006:6006 deephdc/deep-oc-benchmarks_cnn:flavor
```

This command will pull the Docker container from the Docker Hub
[deephdc](https://hub.docker.com/u/deephdc/) repository and start the default command (deepaas-run --listen-ip=0.0.0.0).

### Running via docker-compose

docker-compose.yml allows you to run the application with various configurations via docker-compose.

**N.B!** docker-compose.yml is of version '2.3', one needs docker 17.06.0+ and docker-compose ver.1.16.0+, see https://docs.docker.com/compose/install/

If you want to use Nvidia GPU, you need nvidia-docker and docker-compose ver1.19.0+ , see [nvidia/FAQ](https://github.com/NVIDIA/nvidia-docker/wiki/Frequently-Asked-Questions#do-you-support-docker-compose)


### Building the container

If you want to build the container directly in your machine (because you want
to modify the `Dockerfile` for instance) follow the following instructions:

Building the container:

1. Get the `DEEP-OC-benchmarks_cnn` repository:

    ```bash
    $ git clone https://git.scc.kit.edu/deep/DEEP-OC-benchmarks_cnn
    ```

2. Build the container:

    ```bash
    $ cd DEEP-OC-benchmarks_cnn
    $ docker build -t deephdc/deep-oc-benchmarks_cnn .
    ```

3. Run the container (if you enable JupyterLab during the build, `--build-arg jlab=true`, 
you should also add port 8888, i.e. `-p 8888:8888`)::

    ```bash
    $ docker run -ti -p 5000:5000 -p 6006:6006 deephdc/deep-oc-benchmarks_cnn
    ```

These three steps will download the repository from GitHub and will build the
Docker container locally on your machine. You can inspect and modify the
`Dockerfile` in order to check what is going on. For instance, you can pass the
`--debug=True` flag to the `deepaas-run` command, in order to enable the debug
mode.


## Connect to the API

Once the container is up and running, browse to `http://localhost:5000` to get
the [OpenAPI (Swagger)](https://www.openapis.org/) documentation page.
