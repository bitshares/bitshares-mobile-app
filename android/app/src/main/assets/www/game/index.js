"use strict";

// 接受到 android 消息
function onReceiveFromAndroid(params){
  alert("received")
  alert(params.aaa)
  alert(params.bbb)
}

function bindEvents(){

  // 游戏项点击事件
  var doms = document.getElementsByClassName("game-wrap");
  for ( var i = 0; i < doms.length; i++ ) {
    var dom = doms[i];
    dom.addEventListener('click',function() {
      // Remark 和 Android 交易
      // var api = new BtsApi("bts","btsMethods1",{});
      // api.callAndroid();

      window.location.href = "./game.html"
    });
  }

}

function main(){
  bindEvents()
}

window.addEventListener('load', function() {
  main();
})