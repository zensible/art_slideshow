
artSlideshowApp.controller('HomeCtrl', function ($scope, $routeParams, $route, $rootScope) {

  // For use in debugging w/ the chrome console
  window.scope = $scope;

  // If false, show the loading indicator. If true, show the UI
  $scope.loaded = false;

  $scope.categories = window.categories;
  $scope.current_category = $scope.categories[ parseInt(Cookies.get('current_category') || 0) ];

  $scope.wait_times = [ { caption: "10s", val: 10 }, { caption: "20s", val: 20 }, { caption: "30s", val: 30 }, { caption: "1m", val: 60 }, { caption: "2m", val: 60*2 }, { caption: "5m", val: 60*5 }, { caption: "10m", val: 60*10 }, { caption: "30m", val: 60*30 }, { caption: "1hr", val: 60*60 } ]
  $scope.wait_time = $scope.wait_times[ parseInt(Cookies.get('wait_times') || 0) ];

  $scope.eras = [
    { caption: "ALL", val: "ALL" },
    { caption: "20th century", val: "1900_1999" },
    { caption: "19th century", val: "1800_1899" },
    { caption: "18th century", val: "1700_1799" },
    { caption: "17th century", val: "1600_1699" },
    { caption: "16th century", val: "1500_1599" },
    { caption: "15th century", val: "1400_1499" },
    { caption: "14th century", val: "1300_1399" },
    { caption: "13th century", val: "1200_1299" },
    { caption: "12th century", val: "1100_1199" },
    { caption: "11th century", val: "1000_1199" },
    { caption: "10th century", val: "900_999" },
    { caption: "9th century", val: "800_899" },
    { caption: "8th century", val: "700_799" },
    { caption: "7th century", val: "600_699" },
    { caption: "6th century", val: "500_599" },
    { caption: "5th century", val: "400_499" },
    { caption: "4th century", val: "300_399" },
    { caption: "3rd century", val: "200_299" },
    { caption: "2nd century", val: "100_199" },
    { caption: "1st century", val: "0_99" },
    { caption: "0 BC - 500 BC", val: "-499_-1" },
    { caption: "500 BC - 1000 BC", val: "-999_-500" },
    { caption: "1000 BC - 7000 BC", val: "-7000_-1000" },
  ]
  $scope.current_era = $scope.eras[ parseInt(Cookies.get('current_era') || 0) ];

  function getCookie(name) {
    var value = "; " + document.cookie;
    var parts = value.split("; " + name + "=");
    if (parts.length == 2) return parts.pop().split(";").shift();
  }

  var ui_timeout = null;
  $scope.show_ui_go = function() {
    $('#ui-wait, #ui-category').fadeIn(250)
    clearTimeout(ui_timeout)
    ui_timeout = setTimeout(function() {
      $('#ui-wait, #ui-category').fadeOut(1000)
    }, 10*1000)
  }

  $scope.select_time = function(time) {
    $scope.wait_time = time;
    for (var i = 0; i < $scope.wait_times.length; i++) {
      if ($scope.wait_times[i] == time) {
        Cookies.set('wait_times', i)
      }
    }
  }

  $scope.select_category = function(cat) {
    $scope.current_category = cat;
    clearTimeout(timeout_next);
    getNext(true)
    for (var i = 0; i < $scope.categories.length; i++) {
      if ($scope.categories[i] == cat) {
        Cookies.set('current_category', i)
      }
    }
  }

  $scope.select_era = function(era) {
    $scope.current_era = era;
    clearTimeout(timeout_next);
    getNext(true)
    for (var i = 0; i < $scope.eras.length; i++) {
      if ($scope.eras[i] == era) {
        Cookies.set('current_era', i)
      }
    }
  }

  $scope.img_current = {}
  var img_next = {}
  var timeout_next = null;

  function getNext(initial) {
    $.ajax({
      type: "GET",
      url: "/random_image?category=" + $scope.current_category + "&era=" + $scope.current_era.val,
      success: function(response) {
        if (response['id']) {
          img_next = response;
          timeout_next = setTimeout(function() {
            clearTimeout(timeout_next)

            if (!$scope.loaded) {
              $scope.loaded = true;
              $scope.safeApply()
            }

            var id = img_next['id']
            $('#image').attr('src', "/downloaded/" + id + "-" + getCookie('browser-id') + ".jpg")

            $scope.img_current = img_next
            $scope.safeApply()

            getNext(false)
          }, (initial ? 0 : $scope.wait_time.val * 1000))
        } else {
          $.notify("No images found! Try a less restrictive era / category", "error");
        }
      },
      error: function(xhr, status, err) {
        $.notify("Could not contact the Met's servers. Trying again in 2 minutes.", "error");
        setTimeout(function() {
          getNext(true);
        }, 60*2*1000)
      }
    });
  }

  function init() {
    getNext(true)
  }


  init()
});

