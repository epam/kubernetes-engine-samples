output "instance_names" {
  value = [for vm in google_compute_instance.instance : vm.name]
}
