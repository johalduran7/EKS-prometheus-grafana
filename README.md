# AWS Elastic Kubernetes Stack and ArgoCD Project

This project leverages the stack set up on minikube in the project https://github.com/johalduran7/prometheus-grafana-k8s and provisions ArgoCD.

This is intended to show how to deploy the same stack on EKS and the provisioning via Terraform.

**Prerequisites:**

  - If you have a cluster running locally, like on minikube, you have to check what resources you need on EKS
    ```bash
    $ docker stats
    CONTAINER ID   NAME       CPU %     MEM USAGE / LIMIT   MEM %     NET I/O         BLOCK I/O        PIDS
    b30eae46b085   minikube   130.15%   1.9GiB / 2.148GiB   88.42%    643kB / 537kB   3.01GB / 551MB   995
    ```
    - check the current memory limit, and use the thumb rule,if the limit is 2.4 GB, you use ~3-4GB.

  - check the size of the volumes:
      ```bash
      $ minikube ssh -- docker system df
      TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
      Images          50        26        7.881GB   4.5GB (57%)
      Containers      92        46        72.86kB   34.52kB (47%)
      Local Volumes   2         2         355.3kB   0B (0%)
      Build Cache     0         0         0B        0B
      ```
    - OS + Kubernetes Overhead	6 GB
    - Your Images + Volumes + Containers	~8 GB
    - Safety Buffer	2 GB
    - Recommended EBS Volume	16 GB
  - so, the right fit is t3.medium https://aws.amazon.com/ec2/instance-types/
  - The EBS, 16GB, however, the type of instance accepts 20GB as minimum.

  - The cost is gonna be like: $0.0434 USD per hour

  - Now, the calculation before is just for the worker node, whereas for the control plane node (master) is 0.1 USD in most of the regions. So the total of the EKS cluster per hour is ~$0.1434 per hour.


### Deployments

This project deploys the following components:

-   **Node.js App:** A web application that allows users to upload and retrieve images, utilizing a PostgreSQL database for storage. NOTE: The scope of the project doesn't comprise development skills about the application itself. This is intended to show the configuration of Grafana and Prometheus as well as the configuration to scrape metrics. 
-   **PostgreSQL:** A robust relational database management system used to persist image data.
-   **Prometheus:** A powerful monitoring and alerting toolkit that collects metrics from the deployed applications and infrastructure.
-   **Grafana:** A data visualization and monitoring tool that provides dashboards to visualize metrics collected by Prometheus.
-   **ArgoCD:** Continuous Deployment implementation for NodeJS App.
<table>
  <tr>
    <td><img src="./resources/k8s-app-eks.jpg" alt="Setup" width="200"></td>
    <td><img src="./resources/grafana-postgres.jpg" alt="Setup" width="200"></td>
    <td><img src="./resources/grafana-metrics.jpg" alt="Setup" width="200"></td>
    <td><img src="./resources/eks-cluster.jpg" alt="Setup" width="200"></td>
    <td><img src="./resources/argocd_1.4.jpg" alt="Setup" width="200"></td>
  </tr>
</table>

### How to Run

1.  **EKS Setup:**
  - Deploying EKS using terraform.
    - reference: https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html
    - Explanation of the resources deployed:
      - cluster iam role: aws_iam_role.eks_cluster_role
        - policies attached: 
          - arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
      - node iam role: aws_iam_role.eks_node_role
        - policies attached: 
          - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
          - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
          - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
      - Networking:
        - default VPC used, for simplicity
        - NOTE: There should be at least 2 AZs to guarantee fault tolerance.
      - aws_eks_clustr.eks
      - aws_eks_node_group.eks_nodes
      
    - NOTE: It takes up to 15m
    - the eks_node_role should allow the node to assum the roles:
      - "ec2.amazonaws.com","eks.amazonaws.com"
    - go to the repository ./terraform_eks and apply the changes:
        ```bash
        terraform apply -auto-approve
        ```
    - Configure Kubectl to track EKS and not minikube:
    	- confirm the current context: 
          ```bash
      	  kubectl config current-context
          ```
    	- Add your EKS without removing minikube: 
          ```bash
      		aws eks update-kubeconfig --region your-region --name your-cluster-name
          ```
          
          ```bash
      		aws eks update-kubeconfig --region us-east-1 --name eks-cluster
          ```
    	- verify that the cluster is connected
        ```bash
        john@john-VirtualBox:~/EKS-prometheus-grafana/terraform_eks$ kubectl config get-contexts 
        CURRENT   NAME                                                     CLUSTER                                                  AUTHINFO                                                 NAMESPACE
        *         arn:aws:eks:us-east-1:<ACCOUNT_ID>:cluster/eks-cluster   arn:aws:eks:us-east-1:<ACCOUNT_ID>:cluster/eks-cluster   arn:aws:eks:us-east-1:<ACCOUNT_ID>:cluster/eks-cluster   
        john@john-VirtualBox:~/EKS-prometheus-grafana/terraform_eks$ kubectl get nodes
        NAME                            STATUS   ROLES    AGE   VERSION
        ip-172-31-35-173.ec2.internal   Ready    <none>   10m   v1.32.1-eks-5d632ec
        ```
        
    This is the private IP address of your EC2
  
    - Granting IAM user permissions to see EKS resources
      - Your IAM user won't have access to EKS resources even if it's the admin. This is because we have to add the user to the configmap aws-auth in the kube-system namespace.
      - current config of the auth-file
        ```bash
        $ kubectl get configmap aws-auth -n kube-system -o yaml
        apiVersion: v1
        data:
          mapRoles: |
            - groups:
              - system:bootstrappers
              - system:nodes
              rolearn: arn:aws:iam::ACCOUNT_ID:role/eks-node-role
              username: system:node:{{EC2PrivateDNSName}}
        kind: ConfigMap
        metadata:
          creationTimestamp: "2025-03-09T13:06:05Z"
          name: aws-auth
          namespace: kube-system
          resourceVersion: "831"
          uid: f5476462-b4dd-4ec5-95af-f7419d2d5525
        ```
      
      - Adding my AWS user to mapUsers:
        ```bash
          $ kubectl edit configmap aws-auth -n kube-system
          apiVersion: v1
          data:
            mapRoles: |
              - groups:
                - system:bootstrappers
                - system:nodes
                rolearn: arn:aws:I am::<ACCOUNT_ID>:role/eks-node-role
                username: system:node:{{EC2PrivateDNSName}}
            mapUsers: |
              - userarn: arn:aws:iam::<ACCOUNT_ID>:user/john
                username: john
                groups:
                  - system:masters
              - userarn: arn:aws:iam::<ACCOUNT_ID>:root
                username: root-admin
                groups:
                  - system:masters
          kind: ConfigMap
          metadata:
            creationTimestamp: "2025-03-09T13:06:05Z"
            name: aws-auth
            namespace: kube-system
            resourceVersion: "6684"
            uid: f5476462-b4dd-4ec5-95af-f7419d2d5525
        ```
      - Alternative, just patch it:
          ```bash
          kubectl patch configmap aws-auth -n kube-system --type merge -p '{
            "data": {
              "mapRoles": "- groups:\n  - system:bootstrappers\n  - system:nodes\n  rolearn: arn:aws:iam::<ACCOUNT_ID>:role/eks-node-role\n  username: system:node:{{EC2PrivateDNSName}}\n",
              "mapUsers": "- userarn: arn:aws:iam::<ACCOUNT_ID>:user/john\n  username: john\n  groups:\n    - system:masters\n- userarn: arn:aws:iam::<ACCOUNT_ID>:root\n  username: root-admin\n  groups:\n    - system:masters\n"
            }
          }'
          ```
      -  This will add your AWS user to the built-in Kubernetes RBAC (Role-Based Access Control)

    - Install eksctl (linux)
      ```bash
    	curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    	sudo mv /tmp/eksctl /usr/local/bin
      eksctl version
    		0.205.0
      ```
    - Create IAM OIDC provider:
      ```bash
    	eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster eks-cluster --approve
      ```
    - The EC2 instance sets IMDSv2 as required, this will prevent the aws-load-balancer-controller pods from extracting metadata such as the vpc_id, so you have to set it to optional:
      ```bash
    	aws ec2 modify-instance-metadata-options \
    	--instance-id i-04b7232997b2a6c27 \
    	--http-endpoint enabled \
    	--http-tokens optional
      ```
    	For any custom setting, you have to create a launch_template for the eks node group.

2.  **Prepare the Node.js Application Image:**

    Before deploying the Node.js application, ensure it is properly initialized:

    1.  Navigate to the `app` directory:

        ```bash
        cd app
        ```

    2.  Initialize a Node.js project:

        ```bash
        npm init -y
        ```

    3.  Install the required dependencies:

        ```bash
        npm install express ejs multer pg
        ```

    4.  Apply Terraform to push the Docker image to ECR:

        ```bash
        cd ./terraform && terraform init && terraform apply -auto-approve
        ```

        Obtain the repository name from the Terraform output and update the `repository` value in `./app/k8s/values.override.yaml`. Note that `values.yaml` is a placeholder and should not be modified.

3.  **Create the Kubernetes Namespace:**

    Create a dedicated namespace for the project:

    ```bash
    kubectl apply -f ./k8s-namespace/namespace.yaml
    # or
    kubectl create namespace prometheus-grafana-k8s
    ```

    You can also set the current namespace for `kubectl` commands:

    ```bash
    kubectl config set-context --current --namespace=prometheus-grafana-k8s
    ```

4.  **Deploy PostgreSQL:**

    Deploy the PostgreSQL database using Helm:

    ```bash
    helm install k8s-postgres ./postgres/k8s -f ./postgres/k8s/values.override.yaml -n prometheus-grafana-k8s
    ```

    **Note:** If desired, you can set the current namespace as the default for `kubectl` using the command provided above.

5.  **Authenticate with ECR:**

    If your Node.js application image is hosted on ECR, authenticate with the registry. This example uses the AWS CLI for simplicity:

    ```bash
    aws ecr get-login-password --region us-east-1 | \
    kubectl create secret docker-registry ecr-registry-credentials \
    --docker-server=<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS --docker-password=$(aws ecr get-login-password --region us-east-1) \
    -n prometheus-grafana-k8s
    ```

    **Note:** ECR login credentials expire after 12 hours and need to be refreshed.

6.  **Deploy the Node.js Application:**

    Deploy the Node.js application using Helm:

    ```bash
    helm install k8s-app ./app/k8s -f ./app/k8s/values.override.yaml -n prometheus-grafana-k8s
    ```

    The application will automatically create the necessary database tables if they do not exist.

    Verify that the PostgreSQL and Node.js application pods are running:

    ```bash
    helm list
    kubectl get pod
    ```

    Example output:

    ```
    john@john-VirtualBox:~/prometheus-grafana-k8s$ helm list
    NAME        	NAMESPACE             	REVISION	UPDATED                                	STATUS  	CHART         	APP VERSION
    k8s-app     	prometheus-grafana-k8s	5       	2025-03-01 20:25:44.424525028 -0500 -05	deployed	k8s-app-0.1.0 	1.0.0
    k8s-postgres	prometheus-grafana-k8s	1       	2025-03-01 19:21:49.420486707 -0500 -05	deployed	postgres-0.1.0	15.0
    john@john-VirtualBox:~/prometheus-grafana-k8s$ kubectl get pod
    NAME                       READY   STATUS    RESTARTS   AGE
    k8s-app-547dbf6dcc-2n7bk   1/1     Running   0          13m
    postgres-7c9886f7d-tr8bx   1/1     Running   0          77m
    john@john-VirtualBox:~/prometheus-grafana-k8s$
    ```

7.  **Update the Node.js Application:**

    Just in case you have to update the app. You can skip this step. When you make changes to the Node.js application code (`app.js`), rebuild the Docker image and apply the changes using Terraform. Then, restart the deployment:

    ```bash
    kubectl rollout restart deployment k8s-app -n prometheus-grafana-k8s
    ```

    The changes will be reflected in the application.

    Example:

    ```
    john@john-VirtualBox:~/prometheus-grafana-k8s$ kubectl rollout restart deployment k8s-app -n prometheus-grafana-k8s
    deployment.apps/k8s-app restarted
    john@john-VirtualBox:~/prometheus-grafana-k8s$ kubectl get pod
    NAME                       READY   STATUS              RESTARTS   AGE
    k8s-app-547dbf6dcc-2n7bk   1/1     Running             0          60m
    k8s-app-68456754bb-mvb9g   0/1     ContainerCreating   0          3s
    postgres-7c9886f7d-tr8bx   1/1     Running             0          124m
    john@john-VirtualBox:~/prometheus-grafana-k8s$
    ```

    The IP mapping won't change; just refresh the page in your web browser.

    At this point, you can view the application, open pgAdmin, and run queries against the database.


8. **Install Prometheus and Grafana:**

    - Install the Storage for GP3:

      ```bash
      kubectl apply -f ./prometheus-grafana-stack/storage-class.yaml -n prometheus-grafana-k8s
      ```    

    - Install the `kube-prometheus-stack` Helm chart:

      ```bash
      helm install k8s-kube-prom-stack prometheus-community/kube-prometheus-stack \
        --namespace prometheus-grafana-k8s \
        -f ./prometheus-grafana-stack/values-kube-stack.yaml
      ```

    The release name `k8s-kube-prom-stack` will be used in the ServiceMonitor for Prometheus to scrape metrics.

9. **Configure Metrics Exporters:**

    Configure metrics exporters for PostgreSQL and the Node.js application. There are several ways to export metrics:

    1.  Export metrics in the application using a Prometheus client library.
    2.  Add Prometheus annotations to the Kubernetes deployment.
    3.  Use a sidecar container to export metrics.
    4.  Use a dedicated metrics exporter.
    5.  Use ServiceMonitors/PodMonitors.
    6.  Manually configure scrape jobs.
    7.  Use Pushgateway.

    I'll use Exporters

    **Install PostgreSQL Exporter:**

    ```bash
    helm install k8s-postgres-exporter prometheus-community/prometheus-postgres-exporter -f ./exporters/postgres-exporter-values.override.yaml -n prometheus-grafana-k8s
    ```

    Access the exporter's web page by forwarding the port:

    ```bash
    kubectl get svc | grep -i exporter
    kubectl port-forward svc/k8s-postgres-exporter-prometheus-postgres-exporter 9187:80
    ```

    Check if the exporter has detected PostgreSQL by visiting `http://localhost:9187/metrics`. Look for `pg_up 1`.

    you should see something along these lines: 
    ```bash
    # HELP pg_up Whether the last scrape of metrics from PostgreSQL was able to connect to the server (1 for yes, 0 for no).
    # TYPE pg_up gauge
    pg_up 1
    ```

    Deploy a ServiceMonitor for the PostgreSQL exporter:

    ```yaml
    serviceMonitor:
      enabled: true
      labels:
        release: prometheus
    ```

    Verify the ServiceMonitor deployment:

    ```bash
    kubectl get servicemonitor
    ```
    Now, you add a nice dashboard from https://grafana.com/grafana/dashboards/455-postgres-overview/


    **Add ServiceMonitor for Node.js App:**
    The metrics exported by the application really depends on you. I added metrics to count the total of requests and the count of type of requests to DB. This may be meaningless but it's out of the scope of this project.

    Create `exporters/k8s-app-exporter-values.yaml`:

    ```yaml
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: k8s-app-monitor
      namespace: prometheus-grafana-k8s
      labels:
        release: k8s-kube-prom-stack
    spec:
      selector:
        matchLabels:
          app: k8s-app
      endpoints:
        - port: metrics
          path: "/metrics"
          interval: 30s
    ```

    Apply the ServiceMonitor:

    ```bash
    kubectl apply -f ./exporters/k8s-app-exporter-values.yaml
    ```
    You can leverage Loki to visualize the metrics or logs from the app

    
## 10. Access Resources

There are four ways to access resources in the EKS cluster:

### 1. Port Forward to Access Locally
Just like on Minikube, you can use port forwarding:
```bash
kubectl port-forward svc/<app-service> <external-port>:<servicePort> -n <namespace>
kubectl port-forward svc/pgadmin-service 9091:80 -n prometheus-grafana-k8s
```
Access the service on `localhost:9091`.

### 2. Exposing with a LoadBalancer Service (Public Access)
**IMPORTANT NOTE:** For every service of type `LoadBalancer`, a classic load balancer will be created on AWS. For testing purposes, exposing only one service is recommended. The application itself was chosen.

This load balancer is **not** managed by Terraform and must be deleted manually.

- Configure a service with `type: LoadBalancer`.
- Apply the configuration (this service is already running as it was installed by Helm):
  ```bash
  kubectl apply -f ./app/k8s/templates/app-service-lb.yaml
  ```
- Check the external endpoint:
  ```bash
  kubectl get service -n prometheus-grafana-k8s
  ```
  Example output:
  ```bash
  NAME               TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)        AGE
  k8s-app            NodePort       10.100.39.10    <none>                                                                    80:32420/TCP   50m
  k8s-app-lb         LoadBalancer   10.100.48.133   adbef8db6d3ea4370914e2c22989771a-1791137444.us-east-1.elb.amazonaws.com   80:31949/TCP   3m42s
  ```
- Access the service at:
  ```
  http://adbef8db6d3ea4370914e2c22989771a-1791137444.us-east-1.elb.amazonaws.com:80
  ```
![Setup](./resources/k8s-app-eks.jpg)
### 3. Exposing with an Ingress Controller

- **Create an IAM Role for the ServiceAccount** (different from the cluster IAM role):
  ```bash
  eksctl create iamserviceaccount \
    --cluster eks-cluster \
    --namespace kube-system \
    --name aws-load-balancer-controller \
    --attach-policy-arn arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve
  ```
  **Note:** The `AWSLoadBalancerControllerIAMPolicy` was already created via Terraform.

- This command will create a CloudFormation stack and an IAM role:
  ```bash
  eksctl-eks-cluster-addon-iamserviceaccount-ku-Role1-qrjksIYLp300
  ```

- **Install AWS Load Balancer Controller (instead of Nginx)**:
  ```bash
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update

  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=eks-cluster \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=us-east-1
  ```

- Ensure **IMDSv2** is set to optional.
- To refresh the controller deployment:
  ```bash
  kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
  ```

- **Tag subnets for ALB discovery**:
  ```bash
  aws ec2 create-tags --resources subnet-f5c09ab8 subnet-9631a6c9 \
    --tags Key=kubernetes.io/role/elb,Value=1
  ```

- **Troubleshoot issues** by checking logs:
  ```bash
  kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller | grep -i error
  ```

- **Deploy the ingress resource**:
  ```bash
  kubectl apply -f ./ingress/templates/k8s-grafana-ingress.yaml -n prometheus-grafana-k8s
  ```

- **Check the ingress address**:
  ```bash
  kubectl get ingress
  ```
  Example output:
  ```bash
  NAME                  CLASS   HOSTS   ADDRESS                                                                   PORTS   AGE
  k8s-grafana-ingress   alb     *       k8s-grafanaingressgro-12ecc227c1-2111689879.us-east-1.elb.amazonaws.com   80      2m1s
  ```
- Access the service at:
  ```
  http://k8s-grafanaingressgro-12ecc227c1-2111689879.us-east-1.elb.amazonaws.com
  ```
![Setup](./resources/grafana-postgres.jpg)
### 4. Using AWS SSM Port Forwarding

**Note:** The SSM Agent must be installed on the EC2 instance.

- Start a session and port forward:
  ```bash
  aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
  kubectl port-forward svc/pgadmin-service 8080:80 -n your-namespace
  ```


10. **Clean up:**
  ```bash
  Delete the stack created on cloudformation
  Delete the load balancers
  Delete the target groups
  Delete security groups created by K8S and not tracked by Terraform
  Delete the volumes
  This process takes a lot of time so you can manually delete some resources to speed it up
  Destroy infrastructure:
  $ terraform destroy -auto-approve
  ```

## 11. Deploying ArgoCD
  - Create a namespace:
    ```bash 
  	kubectl create namespace argocd
    ```
  - Install ArgoCD:
    ```bash
  	kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd
    ```
  - Expose ArgoCD GUI.
    ```bash
  	kubectl port-forward svc/argocd-server 9091:80 -n argocd
    ```
  	- via Service Classic Load Balancer:
      ```bash
      $ cat ArgoCD/argocd-service-lb.yaml
      apiVersion: v1
      kind: Service
      metadata:
        name: argocd-server-lb
        namespace: argocd
        labels:
          app: argocd-server-lb
      spec:
        selector:
          app.kubernetes.io/name: argocd-server  # The selector, it uses the service to know which pod to send the traffic to
  			  ports:
  			  - name: http
  			    port: 80
  			    protocol: TCP
  			    targetPort: 8080
  			  - name: https
  			    port: 443
  			    protocol: TCP
  			    targetPort: 8080
  			  type: LoadBalancer
      ```
  	- deploy svc:
     ```bash
  		kubectl apply -f ArgoCD/argocd-service-lb.yaml
     ```
  	- access on https (e.g.):
  		https://aa3933c344bce427ea85ed2acedc6df7-1216971548.us-east-1.elb.amazonaws.com/
  - get the initial Admin password:
    ```bash
  	kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode
    ```
  	e.g.:  admin/sQdWUM69Wd7W2nSh
  - Configure the NodeJS app for argocd:
  	- apply changes:
     ```bash
  		kubectl apply -f ArgoCD/nodejs-app.yaml -n argocd
     ```
  - Check that the Application is out of sync:
    ```bash
  	$ kubectl get Applications -n argocd
  	NAME         SYNC STATUS   HEALTH STATUS
  	nodejs-app   OutOfSync     Progressing
    ```
  - ArgoCD will try to sync with the repo but it won't be able to pull the latest image because of 
  lack of permissions. Let's set up the permissions:

  	- Create the policy (terraform code includes it):
      ```bash
  		resource "aws_iam_policy" "ecr_readonly" {
  		  name        = "ECRReadOnlyPolicy"
  		  description = "Allows read-only access to ECR repositories"
  		  policy = jsonencode({
  		    Version = "2012-10-17"
  		    Statement = [
  		      {
  		        Effect   = "Allow"
  		        Action   = [
  		          "ecr:GetDownloadUrlForLayer",
  		          "ecr:BatchGetImage",
  		          "ecr:GetAuthorizationToken"
  		        ]
  		        Resource = "*"
  		      }
  		    ]
  		  })
  		}
      ```
  	- Attach the policy to ArgoCD's ServiceAccount:
     ```bash
  		eksctl create iamserviceaccount \
      --name argocd-sa \
      --namespace argocd \
      --cluster eks-cluster \
      --attach-policy-arn arn:aws:iam::948586925757:policy/ECRReadOnlyPolicy \
      --approve
     ```
  	- Patch the argocd deployment:
     ```bash
  	 kubectl patch deployment argocd-repo-server -n argocd --type='json' -p='[{"op": "add", "path": "/spec/template/spec/serviceAccountName", "value": "argocd-sa"}]'
     ```
  - Whenever the tag changes in the manifest, for instance, when CI pipeline pushes a new tag to ECR and updates the manifest of the app, ArgoCD reads it every 3 minutes and shows the changes in Differ, then you can either automatically or manually sync rollout the new tag:
    ```bash
  	grep -A4 'image:' app/k8s/values.yaml 
  	image:
  	  repository: 948586925757.dkr.ecr.us-east-1.amazonaws.com/k8s-app 
  	  tag: "1.1.1"
  	  sspullPolicy: IfNotPresent
    ```
  	- To push a new image, use the terraform_ecr IaC
     
 - Releasing via ArgoCD
   - The application will show the current version 1.1.2
     ![Setup](./resources/argocd_1.1.jpg)
     ![Setup](./resources/argocd_1.2.jpg)
     
   - When releasing a new tag and changing the manifest with a new tag of the image, ArgoCD will detect the changes in the repository. The status is OutOfSync:
     ![Setup](./resources/argocd_1.3.jpg)
     
   - Finally, depending on the config that you have for your Application, it can automatically or manually release the new tag and pull the image:
     ![Setup](./resources/argocd_1.4.jpg)
     ![Setup](./resources/argocd_1.5.jpg)
  
 
      

 
     
     
   




