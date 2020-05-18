# VirtAI Orion Virtual GPU Platform

VirtAI Orion Platform can virtualize GPUs and create GPU resource pool to:

* Aggregate physical GPUs resides on different servers (which are both difficult to manage and use!)
  * Easy to manage!
  * Easy to use!
* Create multiple virtual GPUs from a single physical GPU (provide isolation and throttling among light weighted workloads and thus improving GPU utilization)
  * Resource isolation and throttling
  * Improving GPU utilization
  * Save money!
* Turn every CPU server into GPU server
  * Access remote GPU on a CPU only server. No sweat!
* Dynamic scaling
  * Change Orion virtual GPU settings without rebooting!

## Prerequsitions

Please visit [VirtAI Tech](https://virtai.tech/) for more information.

* Properly installed NVidia GPU drivers on GPU nodes. Orion will **NOT** try to handle these drivers.
* Container runtime `containerd` with version >= 1.3.2
  * NVidia docker runtime enabled on GPU nodes.
  * Check the container runtime by `kubectl get node [nodename]`
* Orion assumes the network interface to be used has exactly the same name among all nodes (e.g. `eth0`). If not, it's users' responsibility to properly config these network interface names.
* (recommaned) Properly configured RDMA environment for best performance.
  * If Infiniband is used, OFED should be properly installed.

## Chart Details

This chart will do the following:

* Deploy Orion controller (with web portal)
* Deploy Orion server
* Deploy Orion kubernetes device plugin
* Deploy Orion scheduler

To use Orion, you may want to deploy [Orion Client](https://virtai.tech/)

## Use Orion VGPU

Please visit [VirtAI Tech](https://virtai.tech/) to get detailed docs on how to deploy Orion client.

## Useful links

[VirtAI Tech](https://virtai.tech/)

## Activate Your Orion

Don't have a license? Please visit [VirtAI Tech](https://virtai.tech/) to get one trial license for FREE.
