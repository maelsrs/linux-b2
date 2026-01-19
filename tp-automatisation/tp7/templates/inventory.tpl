[webservers]
%{ for name in web_containers ~}
${name} ansible_connection=docker
%{ endfor ~}

[loadbalancer]
${lb_container} ansible_connection=docker
