FROM elixir:alpine

WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock* ./

# Install dependencies
RUN mix deps.get

# Copy all project files
COPY . .

EXPOSE 4000

CMD ["mix", "run", "--no-halt"]