location / {
	proxy_set_header        Host $host;
	proxy_set_header        X-Real-IP $remote_addr;
	proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_set_header        X-Forwarded-Proto https;
	proxy_pass              https://vlo-web:8443;
}

location /data/ {
	alias   /srv/www-static/data/;
	autoindex on;
}

location /root/ {
	alias   /srv/www-static/root/;
	autoindex on;
}

location /resultsets/ {
	alias   /srv/www-static/resultsets/;
	autoindex on;
}

location /sitemap/ {
	alias   /srv/www-static/sitemap/;
	autoindex on;
}

error_page   500 502 503 504  /50x.html;
location = /50x.html {
	root    /var/lib/nginx/html;
}
