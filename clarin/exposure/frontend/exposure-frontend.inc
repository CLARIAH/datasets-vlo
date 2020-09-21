location ^~ /exposure/ {
	set $frontend exposure-frontend;
	resolver 127.0.0.11 valid=30s;
	
	proxy_set_header        Host $host;
	proxy_set_header        X-Real-IP $remote_addr;
	proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_set_header        X-Forwarded-Proto http;
	proxy_pass              http://$frontend:8080/exposure/;

	auth_basic   "Authentication required";
	auth_basic_user_file  /etc/nginx/exposure-frontend/htpasswd;
}