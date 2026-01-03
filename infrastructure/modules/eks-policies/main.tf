#########################################
# Restrict traffic flow using network policies
##########################################

# Block all ingress and egress traffic within stars namespace
resource "kubernetes_network_policy_v1" "default_deny_stars" {
  metadata {
    name      = "default-deny"
    namespace = "stars"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {}
    }
  }
}

# Block all ingress and egress traffic within the client namespace
resource "kubernetes_network_policy_v1" "default_deny_client" {
  metadata {
    name      = "default-deny"
    namespace = "client"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {

      }
    }
  }
}

# Allow the management-ui to access the star application pods
resource "kubernetes_network_policy_v1" "allow_ui_to_stars" {
  metadata {
    name      = "allow-ui"
    namespace = "stars"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {}
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            role = "management-ui"
          }
        }
      }
    }
  }
}

# Allow the management-ui to access the client application pods
resource "kubernetes_network_policy_v1" "allow_ui_to_client" {
  metadata {
    name      = "allow-ui"
    namespace = "client"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {
      }
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            role = "management-ui"
          }
        }
      }
    }
  }
}

# Allow the frontend pod to access the backend pod within the stars namespace
resource "kubernetes_network_policy_v1" "allow_frontend_to_backend" {
  metadata {
    name      = "backend-policy"
    namespace = "stars"
  }
  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {
        role = "backend"
      }
    }
    ingress {
      from {
        pod_selector {
          match_labels = {
            role = "frontend"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "6379"
      }
    }
  }
}

# Allow the client pod to access the frontend pod within the stars namespace
resource "kubernetes_network_policy_v1" "allow_client_to_backend" {
  metadata {
    name      = "frontend-policy"
    namespace = "stars"
  }

  spec {
    policy_types = ["Ingress"]
    pod_selector {
      match_labels = {
        role = "frontend"
      }
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            role = "client"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "80"
      }
    }
  }
}