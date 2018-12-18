location / {
	proxy_cache             vlo_cache;
	add_header              X-Cache-Status $upstream_cache_status;
	
	proxy_set_header        Host $host;
	proxy_set_header        X-Real-IP $remote_addr;
	proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_set_header        X-Forwarded-Proto $scheme;
	proxy_pass              http://vlo-web:8080;
	
	gzip_min_length 10240;
	gzip_types application/javascript text/javascript  text/html application/x-javascript text/css text/plain application/xml text/xml;
	gzip_proxied any;
	gzip_http_version 1.0;
	
	add_header 'Referrer-Policy' 'origin-when-cross-origin';
	
	location ~ ^/config/(.*) {
		auth_basic				"Authentication required";
		auth_basic_user_file	/etc/nginx/vlo-config-htpasswd;
		proxy_pass              http://vlo-web:8080/config/$1;
	}
}

location ^~ /solr/ {
		proxy_set_header        Host $host;
		proxy_set_header        X-Real-IP $remote_addr;
		proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header        X-Forwarded-Proto http;
		proxy_pass              http://vlo-solr:8983/solr/;
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
