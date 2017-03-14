
var artSlideshowApp = angular.module('artSlideshowApp', ['ngResource', 'ngRoute']);


artSlideshowApp.directive("ngMobileClick", [function () {
    return function (scope, elem, attrs) {
        elem.bind("touchstart click", function (e) {
          console.log("scope.isMobile", scope.isMobile)
          if (!scope.isMobile) {
            e.preventDefault();
            e.stopPropagation();
            return;
          }

          scope.$apply(attrs["ngMobileClick"]);
        });
    }
}])