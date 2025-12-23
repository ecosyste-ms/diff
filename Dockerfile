# =============================================
# Builder stage
# =============================================
FROM ruby:3.4.8-alpine AS builder

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
WORKDIR $APP_ROOT

# Install build dependencies
RUN apk add --no-cache \
  build-base \
  git \
  nodejs \
  postgresql-dev \
  tzdata \
  curl-dev \
  yaml-dev \
  zlib-dev \
  python3 \
  py3-pip \
  openjdk17-jre-headless \
  diffoscope

# Install gems
COPY Gemfile Gemfile.lock $APP_ROOT/
RUN gem update --system \
 && gem install bundler foreman \
 && bundle config --global frozen 1 \
 && bundle config set without 'test' \
 && bundle install --jobs 2

# Copy application code
COPY . $APP_ROOT

# Precompile bootsnap and assets
RUN RAILS_ENV=production bundle exec rake assets:precompile

# =============================================
# Final stage
# =============================================
FROM ruby:3.4.8-alpine

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1
WORKDIR $APP_ROOT

# Install runtime dependencies
RUN apk add --no-cache \
  bash \
  nodejs \
  postgresql-libs \
  tzdata \
  curl \
  yaml \
  jemalloc \
  python3 \
  py3-pip \
  openjdk17-jre-headless \
  diffoscope \
  netcat-openbsd \
  git

# Install Python packages
RUN pip3 install --no-cache-dir --break-system-packages jsbeautifier tlsh

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code
COPY --from=builder $APP_ROOT $APP_ROOT

# Startup
CMD ["bin/docker-start"]
