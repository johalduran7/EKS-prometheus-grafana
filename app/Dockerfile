# Use official Node.js image as base
FROM node:18-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install -y prom-client

COPY . .

EXPOSE 3000

CMD ["node", "app.js"]

# Make sure Nodejs is initialized first:
    # cd app
    # npm init -y
    # npm install express ejs multer pgg