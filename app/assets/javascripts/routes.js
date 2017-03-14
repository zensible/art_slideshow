
if (!window.isBot) {
  angular.module('artSlideshowApp').config(function($routeProvider) {
    return $routeProvider.when('/home', {
      templateUrl: '/template/home'
    }).otherwise({
      templateUrl: '/template/home'
    });
  });
  
}
