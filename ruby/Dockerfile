FROM debian:wheezy
RUN apt-get update && \
  DEBIAN_FRONT_END=noninteractive apt-get install -y \
  ruby

#RUN ln -sf /dev/stderr /usr/local/nginx/logs/error.log


# skip installing gem documentation
RUN echo 'gem: --no-rdoc --no-ri' >> "$HOME/.gemrc"


RUN mkdir -p /usr/src/{app,bundle}
WORKDIR /usr/src/app
#WORKDIR /vagrant

#ONBUILD COPY Gemfile /usr/src/app/
#ONBUILD COPY Gemfile.lock /usr/src/app/
#ONBUILD RUN bundle install

COPY . /usr/src/app/
#COPY Gemfile.lock /usr/src/app/

# install things globally, for great justice
ENV GEM_HOME /usr/local/bundle
ENV PATH $GEM_HOME/bin:$PATH
RUN gem install bundler \
  && bundle config --global path "$GEM_HOME" \
  && bundle config --global bin "$GEM_HOME/bin"

RUN bundle install

# don't create ".bundle" in all our apps
ENV BUNDLE_APP_CONFIG $GEM_HOME

#CMD ["irb"]

#FROM ruby:2.2-onbuild
CMD ["ruby", "-e", "'puts RUBY_VERSION'"]
