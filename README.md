# Orion Kubernetes 部署文档

本文档使用[Helm](http://helm.sh/)将Orion所有组件部署到Kubernetes环境上。

Orion已经与企业级Kubernetes管理平台[Rancher](https://rancher.com)深度整合，你可以通过Rancher中国[应用商店](https://github.com/cnrancher/pandaria-catalog)直接部署Orion。具体请参考应用商店内说明。

## 安装步骤

1. 在可以通过kubectl访问Kubernetes环境的节点上安装Helm工具。如果客户有使用helm，则可以跳过此步骤。

   ```bash
   # 1.1 测试kubectl可以正常工作
   kubectl get nodes
   # 示例输出
   #NAME               STATUS   ROLES               AGE   VERSION
   #ip-172-31-28-1     Ready    worker              24d   v1.17.5
   #ip-172-31-43-188   Ready    worker              24d   v1.17.5
   #ip-172-31-43-87    Ready    controlplane,etcd   24d   v1.17.5
   
   # 1.2 安装helm
   # Ubuntu上可以直接通过snap安装
   # 其它包管理器下安装helm请参考
   # https://helm.sh/docs/intro/install/
   # 或者
   # https://github.com/helm/helm/releases
   sudo snap install helm --classic
   
   # 测试helm可以正常与Kubernetes通信
   helm list
   # 示例输出
   #NAME    NAMESPACE       REVISION        UPDATED STATUS  CHART   APP VERSION
   ```

2. 修改安装配置（下文均假设当前路径与本文档所在路径相同）

   * 所有配置信息都通过`charts/orion-gpu/values.yaml`设置

   * 大部分配置均不需要修改，少数需要修改的配置均通过注释`# Interesting Config:` 标出。关键配置的说明如下：

     | 设置                   | 说明                                                         | 默认值             | 类型   |
     | ---------------------- | ------------------------------------------------------------ | ------------------ | ------ |
     | resources.name         | 暴露给Kubernetes的orion资源名称，客户端在申请orion资源时，需要使用这里设置的资源名称。通常不需要修改。特别和Rancher整合时，修改这个名称将导致Rancher无法正确启动Orion的客户端（Rancher固定使用virtaitech.com/gpu作为Orion资源名） | virtaitech.com/gpu | string |
     | controller.password    | 登录controller webui的密码（用户为admin）。controller的登录地址在使用`helm install`部署时将通过`stdout`输出，请注意查看。 | 空                 | string |
     | controller.enableQuota | controller是否启用quota。写文档的人不清楚这个设置的含义，读文档的人应该会知道。 | false              | bool   |
     | controller.token       | controller的token。调用controller高级api时需要给出这里设置的token才能调用成功。controller的api文档请咨询Ruixue获得。 | 空                 | string |
     | server.cudaVersion     | server镜像内使用的cuda版本，可选值为"9.0","9.1","9.2","10.0","10.1"。需要有对应的server镜像配合，请参考[Image的说明](#image) | 10.1               | string |
     | server.net             | （**关键设置**）Orion bind net的网卡名称。由于在Kubernetes环境上难以在每个节点上独立安装server并指定bind address，这里通过使用bind net来绑定相应网卡（比如RDMA网卡）。这里有一个前提条件：所有需要安装orion server的Kubernetes节点都会绑定到同一个名字的网卡上。如果有节点配置的网卡名称不同，必须请IT、运维人员做相应修改。 | eth0               | string |
     | server.vgpus           | 每个PGPU虚拟出几个VGPU                                       | 4                  | int    |
     | server.ibName          | Infiniband网卡名称？写文档的人从来没有设置并测试过这个值。读文档的人应该明白这个值的含义。 | 空                 | string |
     | license.key            | 新版license。直接作为字符串粘贴到这里即可。注意旧版的license无法使用。 | 空                 | string |
     | scheduler.apiVersion   | controller使用的api版本。scheduler与controller通信时会使用。通常与controller的版本相同。 | 2.2                | string |
     | scheduler.dataVersion  | 同上。                                                       | 2.2                | string |

3. <span id="image">Image名称说明</span>

   * 当前chart为2.2版本，默认的image为[dockerhub](https://hub.docker.com/u/virtaitech)上公开的image。具体为：

     | 组件       | 镜像                                                         | 说明                                                         |
     | ---------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
     | monitor    | `virtaitech/dcgm-export:2.2` `virtaitech/node-exporter:2.2`  | 对应为`nvidia/dcgm-exporter`和`quay.io/prometheus/node-exporter`通常不需要随着orion的版本升级而升级 |
     | controller | `virtaitech/prometheus:2.2` `virtaitech/orion-controller:2.2` | `prometheus:2.2`不需要随着orion版本升级                      |
     | helper     | `virtaitech/orion-helper:2.2`                                | 用于给Kubernetes节点打label，没有深度测试过，部署完成后需要手动检测每个节点的label。 |
     | server     | `virtaitech/orion-server-2.2:cuda10.1`                       | 目前dockerhub上只有`cuda10.1`的镜像                          |
     | plugin     | `virtaitech/orion-plugin:2.2`                                | Kubernetes device plugin                                     |
     | scheduler  | `virtaitech/hyperkube:2.2` `virtaitech/k8s-scheduler-extender:2.2` | `hyperkube`是`gcr.io/google_containers/hyperkube:v1.16.3`的mirror |

   * 自定义使用的镜像

     通常每个组件使用的image可以通过组件下的`image.repository`和`image.version`来设置。例如：

     ```yaml
    helper:
       image:
         repository: virtaitech/orion-helper
         version: "2.2"
     ```
   
     则最终orion helper使用的image为：`virtaitech/orion-helper:2.2`
   
     但是orion server的情况比较特殊，请参考下文说明。
   
   * orion helper说明
   
     Orion部署完成后请通过`kubectl describe node <nodeName>`查看每个node的label，确保`ORION_BIND_ADDR=<ip_address>`已经通过orion helper正确设置。如果没有的话，需要手动添加label:` kubectl label nodes <nodeName> ORION_BIND_ADDR=<ip_address>`。这里`<ip_address>`需要和`server.net`处设置的网卡的ip地址相同。如果orion server在对应节点上启动失败，则orion helper也无法正确打label。
   
   * orion server镜像说明
   
     orion server具体使用的镜像通过`server.image.version`和`server.cudaVersion`的组合指定。如果使用其它镜像，请将image tag成表格中的格式，并设置这两个值。请注意现在DockerHub上只有`2.2`+`10.1`的镜像（`virtaitech/orion-server-2.2:cuda10.1`），如果需要使用其它版本，请使用`docker load`导入镜像到每一个节点的`docker daemon`并打好相应tag，例如`virtaitech/orion-server-2.2:cuda9.1`。或者把镜像push到私有registry上。如果私有registry有访问控制，需要设置`values.yaml` 中`imagePullSecrets`的值。
   
4. 安装部署

   配置好`values.yaml`文件后，就可以通过helm安装所有Orion组件

   ```bash
   # helm可以一键部署orion
   helm install ./charts/orion-gpu/ --generate-name
   
   # 如果想要看到helm生成的所有yaml文件，可以使用debug参数
   helm install ./charts/orion-gpu/ --generate-name --debug
   ```

   部署完成后可以使用`helm list`查看部署状态。示例输出为：

   ```text
   NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS   CHART                           APP VERSION
   orion-gpu-1591596688    default         1               2020-06-08 06:11:28.953306413 +0000 UTC deployed virtaitech-orion-vgpu-1.0.0     2.2        
   ```

   部署完成后可以通过`kubectl get all` 查看部署的Orion组件状态，示例输出为：

   ```text
   NAME                                    READY   STATUS             RESTARTS   AGE
   pod/orion-controller-5bd9578d87-4dm5n   2/2     Running            0          5m49s
   pod/orion-monitor-qxftd                 2/2     Running            0          5m49s
   pod/orion-monitor-s2rjl                 2/2     Running            0          5m49s
   pod/orion-plugin-lwbfk                  1/1     Running            0          5m49s
   pod/orion-plugin-n2jvc                  1/1     Running            0          5m49s
   pod/orion-server-4c6tx                  1/1     Running            0          5m49s
   pod/orion-server-dtltp                  0/1     CrashLoopBackOff   5          5m49s
   
   NAME                                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
   service/kubernetes                  ClusterIP   10.43.0.1       <none>        443/TCP                         26d
   service/orion-controller            ClusterIP   10.43.173.242   <none>        15500/TCP,15501/TCP,15502/TCP   5m49s
   service/orion-controller-nodeport   NodePort    10.43.44.103    <none>        15502:30009/TCP                 5m49s
   
   NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
   daemonset.apps/orion-monitor   2         2         2       2            2           <none>          5m49s
   daemonset.apps/orion-plugin    2         2         2       2            2           <none>          5m49s
   daemonset.apps/orion-server    2         2         1       2            1           <none>          5m49s
   
   NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
   deployment.apps/orion-controller   1/1     1            1           5m49s
   
   NAME                                          DESIRED   CURRENT   READY   AGE
   replicaset.apps/orion-controller-5bd9578d87   1         1         1       5m49s
   ```

   * 在`default` `namespace` 下面，可以看到有`orion-controller`,`orion-monitor`,`orion-plugin`,`orion-server`四个组件。

   * 注意这里有一个`orion-server`挂了。通过`kubectl logs pod/orion-server-dtltp`查看日志，示例输出为：

     ```text
     Device "ens5" does not exist.
     Network interface ens5 dose not have a valid IPv4 address.
     ```

     这里`ens5`为`server.net`的配置。这条log说明Kubernetes集群中有一个节点没有`ens5`网卡，导致`bind net`失败。因此我们要求客户环境内节点使用统一的网卡命名，以便Orion使用。

   我们还需要查看`kube-system`命名空间下的Orion组件，通过执行指令`kubectl get all -n kube-system`，示例输出：

   ```text
   NAME                                          READY   STATUS              RESTARTS   AGE
   pod/canal-hbbdr                               2/2     Running             51         26d
   ......
   pod/metrics-server-6b55c64f86-5z6r4           1/1     Running             21         26d
   pod/orion-helper-49xzz                        1/1     Running             0          12m
   pod/orion-helper-vk2z9                        1/1     Running             0          12m
   pod/orion-scheduler-5c7f495cf-92bpp           2/2     Running             0          12m
   pod/rke-coredns-addon-deploy-job-n9q4z        0/1     Completed           0          26d
   ......
   pod/rke-network-plugin-deploy-job-wc5f9       0/1     Completed           0          26d
   
   ......
   ```

   可以看到有两个组件在`kueb-system`命名空间下：

   * Orion-helper用来给Kubernetes节点打label。如果已经通过手动方式给每个node打上了label，则orion-helper的状态并不重要。但是，即使orion helper处于running状态，也不代表每个节点都已经有了正确的label！请务必手动确认。
   * Orion-scheduler是Orion自己的调度器。通过helm方式部署Orion，不会修改Kubernetes自带的scheduler，但需要客户在启动Orion-Client的时候指定scheduler为`orion-scheduler`。具体可以参考`charts/orion-gpu/README.md`中的说明。

5. 使用

   如果部署一切正常，则可以部署Orion-client来使用Orion VGPU资源。具体可以参考`charts/orion-gpu/README.md`中的说明。
   
6. 如果想要清理到所有Orion的组件，可以使用`helm list`输出的`NAME`进行卸载：

   ```bash
   helm uninstall orion-gpu-1591596688
   ```

## 相关文档

* `charts/orion-gpu/README.md`
* `charts/orion-gpu/templates/NOTES.txt`
* `charts/orion-gpu/app-readme.md`


