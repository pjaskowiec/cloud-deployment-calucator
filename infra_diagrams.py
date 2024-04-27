from diagrams import Diagram, Cluster
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.network import VPC, InternetGateway, NATGateway
from diagrams.aws.network import PublicSubnet, PrivateSubnet
from diagrams.aws.network import ElbClassicLoadBalancer

with Diagram("", show=False, direction="TB", graph_attr={"bgcolor": "transparent", "margin": "0"} ):
    with Cluster("VPC 10.0.0.0/16"):
        vpc = VPC("VPC")
        igw = InternetGateway("IGW")
        vpc >> igw

        with Cluster(""):
            nat = NATGateway("NAT")
            bastion = EC2("Bastion\nHost")
            elb = ElbClassicLoadBalancer("Classic\nLoad Balancer")

        app_server = EC2("CRUD\nApp")
        db_server = RDS("RDS\n(MySQL)")

        vpc >> PublicSubnet("Public Subnet 10.0.0.0/24") >> [nat, bastion, elb]
        vpc >> PrivateSubnet("Private\nSubnet 1\n10.0.2.0/24") >> app_server
        vpc >> PrivateSubnet("Private\nSubnet 2\n10.0.4.0/24") >> db_server
