# Development

## Setup

First things first, you'll need to fork and clone the repository to your local machine.

`git clone https://github.com/ecosyste-ms/diff.git`

The project uses ruby on rails which have a number of system dependencies you'll need to install. 

- [ruby 3.1.3](https://www.ruby-lang.org/en/documentation/installation/)
- [postgresql 14](https://www.postgresql.org/download/)
- [redis 6+](https://redis.io/download/)
- [node.js 16+](https://nodejs.org/en/download/)
- [diffoscope](https://diffoscope.org/)

Once you've got all of those installed, from the root directory of the project run the following commands:

```
bundle install
bundle exec rake db:create
bundle exec rake db:migrate
rails server
```

You can then load up [http://localhost:3000](http://localhost:3000) to access the service.

### Docker

Alternatively you can use the existing docker configuration files to run the app in a container.

Run this command from the root directory of the project to start the service.

`docker compose up --build`

You can then load up [http://localhost:3000](http://localhost:3000) to access the service.

For access the rails console use the following command:

`docker compose exec app rails console`

## Tests

The applications tests can be found in [test](test) and use the testing framework [minitest](https://github.com/minitest/minitest).

You can run all the tests with:

`rails test`

## Background tasks 

Background tasks are handled by [sidekiq](https://github.com/mperham/sidekiq), the workers live in [app/sidekiq](app/sidekiq/).

To process the tasks run the following command:

`bundle exec sidekiq`

You can also view the status of the workers and their queues from the web interface http://localhost:3000/sidekiq

### Docker

If you're using docker you can start the task by running:

`docker compose exec app sh`

to get into the container, and then:

`bundle exec sidekiq`

## Deployment

A container-based deployment is highly recommended, we use [dokku.com](https://dokku.com/).