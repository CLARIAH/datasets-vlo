location / {
	proxy_cache             vlo_cache;
	add_header              X-Cache-Status $upstream_cache_status;
	
	proxy_set_header        Host $host;
	proxy_set_header        X-Real-IP $remote_addr;
	proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_set_header        X-Forwarded-Proto $scheme;
	proxy_pass              http://vlo-web:8080;
	
	gzip_min_length 10240;
	gzip_proxied no-cache no-store private expired auth;
	gzip_types application/javascript text/javascript  text/html application/x-javascript text/css text/plain application/xml text/xml;
}

location ~ ^/(data|root|resultsets|sitemap)/(.*) {
	alias   /srv/www-static/$1/$2;
	autoindex on;
}

location ~ ^/(robots.txt|google.*\.html)$ {
	alias /srv/www-static/root/$1;
}

location = /tour {
	return	301 " /#tour";
}


error_page   500 502 503 504  /50x.html;
location = /50x.html {
	root    /var/lib/nginx/html;
}
