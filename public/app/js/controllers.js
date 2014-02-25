'use strict';

var futureMeControllers = angular.module('futureMeControllers', []);

futureMeControllers.controller('homeCtrl', [
  '$scope', '$http',
  function($scope, $http) {
    
  }]);


futureMeControllers.controller('industriesCtrl', [
  '$scope', '$http',
  function($scope, $http) {
    $http.get("/industries").success(function(response){
      $scope.industries = response;   
    });

    // $scope.showIndustry = function(){

    //   $http.get("/industries/")  
    // }
  }]);








