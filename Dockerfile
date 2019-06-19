From ruby:2.6.3-alpine

RUN apk add --update build-base libffi-dev

WORKDIR /opt
COPY . .

ENV PORT 8080
ENV RACK_ENV production

# https://github.com/docker-library/docs/blob/master/ruby/content.md#encoding
ENV LANG C.UTF-8

RUN bundle install --system --without=test development

RUN rake static

FROM nginx:latest
COPY nginx.conf /etc/nginx/conf.d/default.conf
WORKDIR /usr/share/nginx/html
COPY --from=0 /opt/build/ .
RUN ls -alh
EXPOSE 8080
