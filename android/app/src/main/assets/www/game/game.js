"use strict";

var WINDOW_WIDTH = window.outerWidth;
var WINDOW_HEIGHT = window.outerHeight;
var dom_pop_window = null;

function onReceiveFromAndroid(params){
  alert("回调了")
  const type = params.type;
  if (type === "submit_response") {
    alert("提交成功: " + params.amount + " BTS");
  }
}

function bindEvents(){

  // 开始游戏按钮
  document.getElementById("start").addEventListener('click',function() {
    dom_pop_window.style.display = "block";
  });

  // 设置按钮
  document.getElementById("setting").addEventListener('click',function() {
    alert("setting")
  });

  // 弹窗关闭按钮
  document.getElementById("pop-content-title-close").addEventListener('click',function() {
    dom_pop_window.style.display = "none";
  });

  // 确认支付按钮
  document.getElementById("submit").addEventListener('click',function() {
    // TODO 验证金额格式
    var amount = document.getElementById("input-bid").value;

    var api = new BtsApi("bts","gameDuobaoSubmit",{amount: amount});
    api.callAndroid();
  });


}

function setStyle(){
  var dom_pop_window_back = document.getElementById("pop-back");
  dom_pop_window.style.height = WINDOW_HEIGHT * 0.7 + "px";
  dom_pop_window.style.top = WINDOW_HEIGHT * 0.15 + "px";
  dom_pop_window_back.style.height = WINDOW_HEIGHT * 0.7 + "px";
}

function init(){
  dom_pop_window = document.getElementById("pop-window");
}

function main(){
  init();
  setStyle();
  bindEvents();
}

window.addEventListener('load', function() {
  main();
})