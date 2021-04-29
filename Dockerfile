FROM ruby:2.7.2

RUN mkdir /app
WORKDIR /app
COPY . .

RUN gem install bundler:2.1.4 && \
    gem update --system && \
    gem install grpc --platform=universal-darwin

CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
