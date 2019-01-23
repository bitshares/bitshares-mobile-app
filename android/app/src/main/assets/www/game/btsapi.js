"use strict";

class BtsApi {

  constructor(base, action, params) {
    this.base_name = base;
    this.action_name = action;
    this.params = params;
  }

  toQueryParams() {
    var _this = this;
    // Todo 转换 { p1: 123, p2: 456} => p1=123&p2=456
    var querystr_arr = []; 
    Object.keys(_this.params).forEach(function(key){
      var value = _this.params[key];
      var querystr = key + "=" + value;
      querystr_arr.push(querystr);
    });
    return querystr_arr.join("&")
  }

  callAndroid(){
    var url = "js://" + this.base_name + "/" + this.action_name;
    if ( this.params ) {
      url = url + "?" + this.toQueryParams()
    }
    document.location = url;
  }

}