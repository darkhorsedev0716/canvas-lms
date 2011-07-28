Request/Response Basics
=======================

Schema
------

All API access is over HTTPS and is of the form

    /api/v1/<path>.json

All responses are in <a href="http://www.json.org/">JSON format</a>.

Authentication
--------------

### Access Tokens

You can use access tokens to authenticate as any user in the system.
Currently, there are two ways to get an access token:

  * Tokens may be created manually by the user and then given to
the third party for use.  Access tokens can be generated from the user's
profile page.
  * Tokens can be created automatically from third-party apps by
    following the <a href="oauth.html">OAuth2</a> flow.

Note that all requests will need the
"access_token" query parameter set, not just the first request.
Most API calls will only return data that is visible to the
authenticated user.  For example, to list the courses that
your user is enrolled in as a teacher:

    $ curl https://canvas.instructure.com/api/v1/courses.json?access_token=USER_PROVIDED_ACCESS_TOKEN | jsonpretty
    [
      {
        "name": "First Course",
        "id": 123456,
        "course_code": "Course-1",
        "enrollments": [
          {
            "type": "teacher"
          },
          {
            "type": "ta"
          }
        ]
      },
      {
        "name": "Second Course",
        "id": 54321,
        "course_code": "Course-2",
        "enrollments": [
          {
            "type": "teacher"
          }
        ]
      }
    ]

### HTTP Basic Auth

*This authentication approach is deprecated*

You can use HTTP Basic Auth to authenticate with any username/password
combination. Note that all requests will need the Authentication header,
not just the first request. All API requests using Basic Auth will need
to include an API key (developer key) as well. Most API calls will only
return data that is visible to the authenticated user. For example, to
list the courses that your user is enrolled in as a teacher:

    $ curl -u 'YOUR_USER:YOUR_PASS' \
      https://canvas.instructure.com/api/v1/courses.json?api_key=DEVELOPER_API_KEY | jsonpretty
    [
      {
        "name": "First Course",
        "id": 123456,
        "course_code": "Course-1",
        "enrollments": [
          {
            "type": "teacher"
          },
          {
            "type": "ta"
          }
        ]
      },
      {
        "name": "Second Course",
        "id": 54321,
        "course_code": "Course-2",
        "enrollments": [
          {
            "type": "teacher"
          }
        ]
      }
    ]

SSL
---

Canvas Cloud Edition requires all API access to be over SSL, using
HTTPS. By default, open source installs have this requirement as well.
Open source installs are strongly encouraged to require SSL for API
calls, since the username and password are sent in the clear for HTTP
Basic Auth, or the access token for oauth, if SSL is not used.

Note that if you make an API call using HTTP instead of HTTPS, you will
be redirected to HTTPS. However, at that point, the credentials
have already been sent in clear over the internet. Please make
sure that you are using HTTPS.

API Keys
--------

When using HTTP Basic Auth, all requests will require a developer API
key to be sent with the request data. Contact your Canvas LMS
administrator to request an API key. The developer key is not required
when using an access token.

The API is a work in progress, and the web UI for managing API keys is
still in development. If you are running your own Canvas LMS instance,
you will need to generate an API key from the Rails console:

    $ script/console
    > key = DeveloperKey.create!(
        :email => 'your_email',
        :user_name => 'your name',
        :account => Account.default)
    > puts key.api_key

The value of `api_key` is the token you'll need to send with every
request, for example:

    /api/v1/courses.json?api_key=YOUR_KEY

If you have trouble getting your Rails console to start, please see the
Rails console section on our <a href="https://github.com/instructure/canvas-lms/wiki/Troubleshooting">Troubleshooting wiki page</a>.

Object IDs
----------

Throughout the API, objects are referenced by internal ids. You can also
reference objects by sis id, by prepending the sis id with the name of
the sis field, like "sis\_course\_id:". For instance, to retrieve the
list of assignments for a course with sis id of 'A1234':

    /api/v1/courses/sis_course_id:A1234/assignments.json
    
Pagination
----------

Requests that return multiple items will be paginated to 10 items by default. Further pages
can be requested with the `?page` query parameter. You can set a custom per-page amount
with the `?per_page` parameter.

Pagination information is provided in the [link Header](http://www.w3.org/Protocols/9707-link-header.html):

    Link: </courses/:id/discussion_topics.json?page=2&per_page=10>; rel="next",</courses/:id/discussion_topics.json?page=1&per_page=10>; rel="first",</courses/:id/discussion_topics.json?page=5&per_page=10>; rel="last"

The possible `rel` values are:

* next - link to the next page of results. None is sent if there is no next page.
* prev - link to the previous page of results. None is sent if there is no previous page.
* first - link to the first page of results. None is sent if there are no pages.
* last - link to the last page of results. None is sent if there are no pages.
