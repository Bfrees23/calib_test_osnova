## Базовый проект PHP + NGINX

Проект содержит:
* Docker Compose файлы для разработки
* Настроенный контейнер PHP версии 8.3 включая Composer, Xdebug
* Настроенный контейнер NGINX

Параметры точки входа:
* Папка для проекта `src`
* Корневая директория Nginx `public`
* Точка входа `index.php` 

1. Клонировать проект
    ```Bash
    git clone https://gitverse.ru/medneem/BaseProject.git
    ```

2. Перейти в папку с проектом
    ```Bash
    cd ~/BaseProject
    ```

3. Удалить файл `.gitkeep`
    ```Bash
    rm src/.gitkeep
    ```

4. Выполнить билд проекта
    ```Bash
    docker compose -f dev.yml --profile client up -d --build
    ```

5. Зайти в контейнер php
    ```Bash
    docker exec -it php bash
    ```

6. Выполнить установку фреймворка CodeIgniter4
    ```Bash
    composer create-project codeigniter4/appstarter .
    ```

7. [Проверить в браузе](http://localhost)