location / {
	proxy_set_header        Host $host;
	proxy_set_header        X-Real-IP $remote_addr;
	proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_set_header        X-Forwarded-Proto http;
	proxy_pass              http://vlo-web:8080;
}

location ~ ^/(data|root|resultsets|sitemap)/(.*) {
	alias   /srv/www-static/$1/$2;
	autoindex on;
}

error_page   500 502 503 504  /50x.html;
location = /50x.html {
	root    /var/lib/nginx/html;
}
