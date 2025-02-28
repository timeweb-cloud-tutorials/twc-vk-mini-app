# 1) Сборка на Node
FROM node:18-alpine as build

# Создаём рабочую директорию
WORKDIR /app

# Копируем package.json и package-lock.json (если есть)
COPY package*.json ./

# Устанавливаем зависимости
RUN npm install

# Копируем остальной код
COPY . .

# Запускаем сборку фронтенда
RUN npm run build

# 2) Запуск на Node (без nginx)
FROM node:18-alpine as production

WORKDIR /usr/share/app
# Копируем собранные статические файлы из предыдущего этапа
COPY --from=build /app/build .

# Устанавливаем простой сервер, чтобы отдать статику
RUN npm install -g serve

EXPOSE 3000
# Запускаем команду для «serve» фронтенда
CMD ["serve", "-s", ".", "-l", "3000"]
