FROM nginx:stable

# Установим пакеты и сразу настроим таймзону
ENV TZ=Europe/Moscow

RUN apt-get update \
      && apt-get install -y mc cron logrotate tzdata \
      && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
      && echo $TZ > /etc/timezone \
      && rm -rf /var/lib/apt/lists/*

# Копируем глобальный конфиг nginx
COPY ./conf.d/dev.nginx.conf /etc/nginx/nginx.conf

# Копируем виртуальный хост
COPY ./conf.d/dev.default.conf /etc/nginx/conf.d/default.conf

# Рабочая директория для PHP/HTML файлов
WORKDIR /var/www

# Открываем порт
EXPOSE 80

# Запускаем nginx в форграунде
CMD ["nginx", "-g", "daemon off;"]