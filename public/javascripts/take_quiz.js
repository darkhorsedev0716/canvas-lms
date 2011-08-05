/**
 * Copyright (C) 2011 Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

var lastAnswerSelected = null;
var quizSubmission;
I18n.scoped('quizzes.take_quiz', function(I18n) {

  $(document).mousedown(function(event) {
    lastAnswerSelected = $(event.target).parents(".answer")[0];
  }).keydown(function() {
    lastAnswerSelected = null;
  });
  $(document).ready(function() {
    $.scrollSidebar();
    $("#questions").delegate('.group_top,.question,.answer_select', 'mouseover', function(event) {
      $(this).addClass('hover');
    }).delegate('.group_top,.question,.answer_select', 'mouseout', function(event) {
      $(this).removeClass('hover');
    });
    if($("#preview_mode_link").length == 0) {
      window.onbeforeunload = function() {
        quizSubmission.updateSubmission();
        if(!quizSubmission.submitting && !quizSubmission.alreadyAcceptedNavigatingAway) {
          return I18n.t('confirms.unfinished_quiz', "You're about to leave the quiz unfinished.  Continue anyway?");
        }
      };
      $(document).delegate('a', 'click', function(event) {
        if($(this).closest('.ui-dialog,.mceToolbar').length > 0) { return; }
        if(!event.isDefaultPrevented()) {
          var url = $(this).attr('href') || "";
          var hashStripped = location.href;
          if(hashStripped.indexOf('#')) {
            hashStripped = hashStripped.substring(0, hashStripped.indexOf('#'));
          }
          if(url.indexOf('#') == 0 || url.indexOf(hashStripped + "#") == 0) {
            return;
          }
          var result = confirm(I18n.t('confirms.navigate_away', "You're about to navigate away from this page.  Continue anyway?"));
          if(!result) {
            event.preventDefault();
          } else {
            quizSubmission.alreadyAcceptedNavigatingAway = true
          }
        }
      });
    }
    $(".list_question").live('mouseover', function(event) {
      if($(this).hasClass('marked')) {
        $(this).attr('title', I18n.t('titles.come_back_later', "You marked this question to come back to later"));
      } else if($(this).hasClass('answered')) {
        $(this).attr('title', I18n.t('titles.answered', "Answered"));
      } else {
        $(this).attr('title', I18n.t('titles.not_answered', "Haven't Answered yet"));
      }
      $("#" + $(this).attr('id').substring(5)).addClass('related');
    }).live('mouseout', function(event) {
      $("#questions .question_holder .question").removeClass('related');
    });
    $(".jump_to_question_link").live('click', function(event) {
      event.preventDefault();
      var $obj = $($(this).attr('href'));
      $("html,body").scrollTo($obj.parent());
      $obj.find(":input:first").focus().select();
    });
    $("#questions").delegate(":checkbox,:radio,label", 'change mouseup', function(event) {
      if(lastAnswerSelected == $(this).parents(".answer")[0]) {
        $(this).parents(".answer").find(":checkbox,:radio").blur();
        quizSubmission.updateSubmission();
      }
    }).delegate(":text,textarea", 'change blur', function(event, update) {
      if(update !== false) {
        quizSubmission.updateSubmission();
      }
    });
    $(".numerical_question_input").live('keypress', function(event) {
      var string = String.fromCharCode(event.charCode || event.keyCode);
      if(event.charCode == 0 || string == "-" || string == "." || string == "0" || parseInt(string, 10)) {
        $(this).triggerHandler('focus');
      } else {
        $(this).errorBox(I18n.t('errors.only_numerical_values', "only numerical values are accepted"));
        event.preventDefault();
        event.stopPropagation();
      }
    }).live('change blur', function() {
      var val = parseFloat($(this).val());
      if(isNaN(val)) { val = ""; }
      $(this).val(val);
    });
    $(".flag_question").live('click', function() {
      $(this).parents(".question").toggleClass('marked');
      $("#list_" + $(this).parents(".question").attr('id')).toggleClass('marked');
    });
    setInterval(function() {
      $("textarea.question_input").each(function() {
        $(this).triggerHandler('change', false);
      });
    }, 2500);
    $(".question_input").live('change', function() {
      var tagName = $(this)[0].tagName.toUpperCase();
      var val = "";
      if(tagName == "TEXTAREA") {
        val = $(this).editorBox('get_code');
      } else if(tagName == "TEXTAREA" || tagName == "SELECT" || $(this).attr('type') == "text") {
        val = $(this).val();
      } else {
        $(this).parents(".question").find(".question_input").each(function() {
          if($(this).attr('checked') || $(this).attr('selected')) {
            val = true;
          }
        });
      }
      if(val) {
        $("#list_" + $(this).parents(".question").attr('id')).addClass('answered');
      } else {
        $("#list_" + $(this).parents(".question").attr('id')).removeClass('answered');
      }
    }).change();
    $(".hide_time_link").click(function(event) {
      event.preventDefault();
      if($(".time_running").css('visibility') != 'hidden') {
        $(".time_running").css('visibility', 'hidden');
        $(this).text(I18n.t('show_time_link', "Show"));
      } else {
        $(".time_running").css('visibility', 'visible');
        $(this).text(I18n.t('hide_time_link', "Hide"));
      }
    });
    setTimeout(function() {
      $("#question_list .list_question").each(function() {
        if($(this).find(".jump_to_question_link").text() == "Spacer") {
          $(this).remove();
        }
      });
    }, 1000);
    $("#submit_quiz_form").submit(function(event) {
      $(".question_holder textarea.question_input").each(function() { $(this).change(); });
      unanswered = $("#question_list .list_question:not(.answered)").length;
      if(unanswered && !quizSubmission.submitting) {
        var result = confirm(I18n.t('confirms.unanswered_questions', {'one': "You have 1 unanswered question (see the right sidebar for details).  Submit anyway?", 'other': "You have %{count} unanswered questions (see the right sidebar for details).  Submit anyway?"}, {'count': unanswered}));
        if(!result) {
          event.preventDefault();
          event.stopPropagation();
          return false;
        }
      }
      quizSubmission.submitting = true;
    });
    $(".submit_quiz_button").click(function(event) {
      event.preventDefault();
      $("#times_up_dialog").dialog('close');
    });
    setTimeout(function() {
      $(".question_holder textarea.question_input").each(function() {
        $(this).attr('id', 'question_input_' + quizSubmission.contentBoxCounter++);
        $(this).editorBox();
      });
    }, 2000);
    setInterval(quizSubmission.updateTime, 200);
    setInterval(function() {
      var current_user_id = $("#identity .user_id").text() || "none";
      $.ajaxJSON(location.protocol + '//' + location.host + "/simple_response.json?user_id=" + current_user_id + "&rnd=" + Math.round(Math.random() * 9999999), 'GET', {}, function() {
      }, function() {
        ajaxErrorFlash(I18n.t('errors.connection_lost', "Connection to %{host} was lost.  Please make sure you're connected to the Internet before continuing.", {'host': location.host}), request);
      }, {skipDefaultError: true});
    }, 30000);
    setTimeout(function() { quizSubmission.updateSubmission(true) }, 15000);
  });
  quizSubmission = (function() {
    var timeMod = 0;
    return {
      referenceDate: null,
      countDown: null,
      isDeadline: true,
      fiveMinuteDeadline: false,
      oneMinuteDeadline: false,
      submitting: false,
      dialogged: false,
      contentBoxCounter: 0,
      lastSubmissionUpdate: new Date(),
      currentlyBackingUp: false,
      started_at: $(".started_at"),
      end_at: $(".end_at"),
      time_limit: parseInt($(".time_limit").text(), 10) || null,
      updateSubmission: function(repeat) {
        if(quizSubmission.submitting && !repeat) { return; }
        var now = new Date();
        if((now - quizSubmission.lastSubmissionUpdate) < 1000) { return }
        if(quizSubmission.currentlyBackingUp) { return; }
        quizSubmission.currentlyBackingUp = true;
        quizSubmission.lastSubmissionUpdate = new Date();
        var data = $("#submit_quiz_form").getFormData();
        $(".question_holder .question.marked").each(function() {
          data[$(this).attr('id') + "_marked"] = "1";
        });
        $.ajaxJSON($(".backup_quiz_submission_url").attr('href'), 'PUT', data, function(data) {
          quizSubmission.currentlyBackingUp = false;
          if(repeat) {
            setTimeout(function() {quizSubmission.updateSubmission(true) }, 30000);
          }
          if(data && data.end_at) {
            quizSubmission.end_at.text(data.end_at);
            quizSubmission.referenceDate = null;
            if(data.end_at > quizSubmission.end_at.text()) {
              $.flashMessage(I18n.t('notices.extra_time', 'You have been given extra time on this attempt'));
            }
          }
        }, function() {
          var current_user_id = $("#identity .user_id").text() || "none";
          quizSubmission.currentlyBackingUp = false;
          $.ajaxJSON(location.protocol + '//' + location.host + "/simple_response.json?user_id=" + current_user_id + "&rnd=" + Math.round(Math.random() * 9999999), 'GET', {}, function() {
          }, function() {
            ajaxErrorFlash(I18n.t('errors.connection_lost', "Connection to %{host} was lost.  Please make sure you're connected to the Internet before continuing.", {'host': location.host}), request);
          }, {skipDefaultError: true});
          
          if(repeat) {
            setTimeout(function() {quizSubmission.updateSubmission(true) }, 30000);
          }
        }, {timeout: 5000, skipDefaultError: true});
      },
      updateTime: function() {
        var now = new Date();
        var end_at = quizSubmission.time_limit ? quizSubmission.end_at.text() : null;
        timeMod = (timeMod + 1) % 120;
        if(timeMod == 0 && !end_at && !quizSubmission.twelveHourDeadline) {
          quizSubmission.referenceDate = null;
          var end = Date.parse(quizSubmission.end_at.text());
          var now = new Date();
          if(!quizSubmission.time_limit && (end - now) < 43200000) {
            end_at = quizSubmission.end_at.text();
          }
        }
        if(!quizSubmission.referenceDate) {
          $.extend(quizSubmission, timing.setReferenceDate(quizSubmission.started_at.text(), end_at, now));
        }
        if(quizSubmission.countDown) {
          var diff = quizSubmission.countDown.getTime() - now.getTime() - quizSubmission.clientServerDiff;
          if(diff <= 0) {
            diff = 0;
          }
          var d = new Date(diff);
          $(".countdown_seconds").text(d.getUTCSeconds());
          if(diff <= 0 && !quizSubmission.submitting) {
            quizSubmission.submitting = true;
            $("#submit_quiz_form").submit();
          }
        }
        var diff = quizSubmission.referenceDate.getTime() - now.getTime() - quizSubmission.clientServerDiff;
        if(quizSubmission.isDeadline) {
          if(diff < 1000) {
            diff = 0;
          }
          if(diff < 1000 && !quizSubmission.dialogged) {
            quizSubmission.dialogged = true;
            quizSubmission.countDown = new Date(now.getTime() + 10000);
            $("#times_up_dialog").show().dialog({
              title: I18n.t('titles.times_up', "Time's Up!"),
              width: "auto",
              height: "auto",
              modal: true,
              overlay: {
                backgroundColor: "#000",
                opacity: 0.7
              },
              close: function() {
                if(!quizSubmission.submitting) {
                  quizSubmission.submitting = true;
                  $("#submit_quiz_form").submit();
                }
              }
            });
          } else if(diff >    30000 && diff <    60000 && !quizSubmission.oneMinuteDeadline) {
            quizSubmission.oneMinuteDeadline = true;
            $.flashMessage(I18n.t('notices.one_minute_left', "One Minute Left"));
          } else if(diff >   250000 && diff <   300000 && !quizSubmission.fiveMinuteDeadline) {
            quizSubmission.fiveMinuteDeadline = true;
            $.flashMessage(I18n.t('notices.five_minutes_left', "Five Minutes Left"));
          } else if(diff >  1800000 && diff <  1770000 && !quizSubmission.thirtyMinuteDeadline) {
            quizSubmission.thirtyMinuteDeadline = true;
            $.flashMessage(I18n.t('notices.thirty_minutes_left', "Thirty Minutes Left"));
          } else if(diff > 43200000 && diff < 43170000 && !quizSubmission.twelveHourDeadline) {
            quizSubmission.twelveHourDeadline = true;
            $.flashMessage(I18n.t('notices.twelve_hours_left', "Twelve Hours Left"));
          } 
        }
        quizSubmission.updateTimeString(diff);
      },
      updateTimeString: function(diff) {
        var date = new Date(Math.abs(diff));
        var yr = date.getUTCFullYear() - 1970;
        var mon = date.getUTCMonth();
        var day = date.getUTCDate() - 1;
        var hr = date.getUTCHours();
        var min = date.getUTCMinutes();
        var sec = date.getUTCSeconds();
        var times = [];
        if(yr) { times.push(I18n.t('years_count', "Year", {'count': yr})); }
        if(mon) { times.push(I18n.t('months_count', "Month", {'count': mon})); }
        if(day) { times.push(I18n.t('days_count', "Day", {'count': day})); }
        if(hr) { times.push(I18n.t('hours_count', "Hour", {'count': hr})); }
        if(true || min) { times.push(I18n.t('minutes_count', "Minute", {'count': min})); }
        if(true || sec) { times.push(I18n.t('seconds_count', "Second", {'count': sec})); }
        $(".time_running,.time_remaining").text(times.join(", "));
      }
    };
  })();
  function updateTime() {
  }
});
