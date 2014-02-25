'use strict';

//this used to be in our controllers 
// but now that we have more than one
// controller, it's going in here!

//the empty array argument also now holds
//2 items, these are the modules that the
//app depends on
// ngRoutes - allows us to use angular-route.js
// spacecatControllers - al
var futureMeApp = angular.module('futureMeApp', [
  'ngRoute',
  'futureMeControllers',
  // 'spacecatFilters',
  // 'spacecatServices'
]);


futureMeApp.config(['$routeProvider',
  function($routeProvider) {
    $routeProvider.
      when('/', {
        templateUrl: 'app/partials/home.html',
        controller: 'homeCtrl'
      }).
      when('/view',{
        templateUrl: 'app/partials/industries.html',
        controller: 'industriesCtrl'
      }).
      otherwise({
        redirectTo: '/'
      });
  }]);