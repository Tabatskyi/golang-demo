FROM golang:1.21-alpine
RUN apk add --no-cache curl git postgresql-client && curl -sSfL https://raw.githubusercontent.com/cosmtrek/air/master/install.sh | sh -s -- -b /usr/local/bin
WORKDIR /silly-demo
COPY ../ /silly-demo
RUN GOOS=linux GOARCH=amd64 go build -o golang-demo
COPY ./db_schema.sql /silly-demo/db_schema.sql
CMD psql -h $DB_ENDPOINT -p $DB_PORT -U $DB_USER -d postgres -f /silly-demo/db_schema.sql && air
