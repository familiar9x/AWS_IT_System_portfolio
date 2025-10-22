FROM public.ecr.aws/docker/library/node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm i --omit=dev
COPY . .
EXPOSE 8001
CMD ["node","index.js"]
