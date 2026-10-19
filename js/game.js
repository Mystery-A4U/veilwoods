import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js';
import { GLTFLoader } from 'https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/loaders/GLTFLoader.js';

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x89a8a0);
scene.fog = new THREE.FogExp2(0x789187, 0.014);

const camera = new THREE.PerspectiveCamera(72, innerWidth/innerHeight, 0.05, 180);
camera.position.set(0,1.65,25);

const renderer = new THREE.WebGLRenderer({antialias:false,powerPreference:'high-performance'});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.6));
renderer.setSize(innerWidth,innerHeight);
renderer.shadowMap.enabled = false;
renderer.outputColorSpace = THREE.SRGBColorSpace;
document.querySelector('#game').appendChild(renderer.domElement);

const clock = new THREE.Clock();
const raycaster = new THREE.Raycaster();
const loader = new GLTFLoader();

const world = new THREE.Group();
scene.add(world);

const mats = {
  grass:new THREE.MeshLambertMaterial({color:0x2e5b2d}),
  dirt:new THREE.MeshLambertMaterial({color:0x665039}),
  wood:new THREE.MeshLambertMaterial({color:0x70452a}),
  roof:new THREE.MeshLambertMaterial({color:0x263b2b}),
  wall:new THREE.MeshLambertMaterial({color:0x9b7650}),
  leaf:new THREE.MeshLambertMaterial({color:0x1c4d22}),
  leaf2:new THREE.MeshLambertMaterial({color:0x2e6d2e}),
  stone:new THREE.MeshLambertMaterial({color:0x4d524d}),
  water:new THREE.MeshLambertMaterial({color:0x2d7e91}),
  fire:new THREE.MeshBasicMaterial({color:0xff8a18}),
  red:new THREE.MeshLambertMaterial({color:0x8b1717}),
  white:new THREE.MeshLambertMaterial({color:0xd9ddd4}),
  green:new THREE.MeshLambertMaterial({color:0x1fe27b,emissive:0x064b26,emissiveIntensity:1.5})
};

const state = {
  day:1,time:8, hp:100,hunger:100,thirst:100,wood:0,berries:0,medicine:0,
  campLevel:1, redAxe:false, night:false, boss:false, emerald:false, win:false,
  move:new THREE.Vector2(), yaw:0,pitch:0,sprinting:false,started:false,
  speed:4.5, messageTimer:0
};

const interactables=[];
const enemies=[];
const trees=[];

function box(w,h,d,mat,x,y,z,group=world){
  const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);
  m.position.set(x,y,z); group.add(m); return m;
}
function cyl(r,h,mat,x,y,z,seg=8,group=world){
  const m=new THREE.Mesh(new THREE.CylinderGeometry(r,r,h,seg),mat);
  m.position.set(x,y,z); group.add(m); return m;
}
function cone(r,h,mat,x,y,z,seg=8,group=world){
  const m=new THREE.Mesh(new THREE.ConeGeometry(r,h,seg),mat);
  m.position.set(x,y,z); group.add(m); return m;
}
function labelObject(obj,name){
  obj.userData.name=name; interactables.push(obj); return obj;
}
function showMessage(t,seconds=2){
  document.querySelector('#message').textContent=t; state.messageTimer=seconds;
}

function buildIsland(){
  const ground=box(110,1,110,mats.grass,0,-.5,0);
  // water moat / shoreline
  const water=box(145,.2,145,mats.water,0,-1.0,0);
  ground.renderOrder=2; water.renderOrder=1;
  for(let i=0;i<70;i++){
    const a=Math.random()*Math.PI*2,r=38+Math.random()*13;
    const x=Math.cos(a)*r,z=Math.sin(a)*r;
    cyl(.5+Math.random()*.7,.7,mats.stone,x,.35,z,7);
  }
  // paths
  box(48,.08,4,mats.dirt,0,.04,8);
  box(4,.09,40,mats.dirt,10,.05,-4);
}

function buildHouse(x,z,name,color=mats.wall){
  const g=new THREE.Group(); g.position.set(x,0,z); world.add(g);
  box(7,4,6,color,0,2,0,g);
  const roof=cone(5.2,3.2,mats.roof,0,5.6,0,4,g); roof.rotation.y=Math.PI/4;
  box(1.4,2,.15,mats.wood,0,1,-3.08,g);
  box(1.6,1.4,.12,new THREE.MeshLambertMaterial({color:0x8cc3c0}),-2.0,2.1,-3.1,g);
  box(1.6,1.4,.12,new THREE.MeshLambertMaterial({color:0x8cc3c0}),2.0,2.1,-3.1,g);
  labelObject(g,name);
}
function buildTown(){
  buildHouse(-15,8,'Village House');
  buildHouse(-15,-2,'Village House 2',new THREE.MeshLambertMaterial({color:0x8c6549}));
  buildHouse(-15,-12,'Village House 3',new THREE.MeshLambertMaterial({color:0x6e7d7f}));
  buildHouse(0,1,'Meat Shop',new THREE.MeshLambertMaterial({color:0x784541}));
  buildHouse(18,6,'Vegetable Shop',new THREE.MeshLambertMaterial({color:0x52744b}));
  buildHouse(18,-6,'Market',new THREE.MeshLambertMaterial({color:0x76643b}));
  buildHouse(2,-12,'Hospital',new THREE.MeshLambertMaterial({color:0xd0d1c9}));
}

function tree(x,z,big=false){
  const g=new THREE.Group(); g.position.set(x,0,z); world.add(g);
  const h=big?5.5:3.4;
  cyl(big?.5:.32,h,mats.wood,0,h/2,0,8,g);
  cone(big?2.6:1.6,big?4.5:3,mats.leaf,0,h+1,0,8,g);
  if(big) cone(2.0,3.5,mats.leaf2,0,h+2.6,0,8,g);
  g.userData={type:'tree',hp:big?7:4,big};
  trees.push(g); interactables.push(g);
}
function plant(x,z,type){
  const g=new THREE.Group(); g.position.set(x,0,z); world.add(g);
  for(let i=0;i<4;i++) box(.08,.35,.28,new THREE.MeshLambertMaterial({color:0x4b8b35}), (i-1.5)*.12,.18,0,g);
  g.userData={type}; interactables.push(g);
}
function buildForest(){
  for(let i=0;i<130;i++){
    const a=Math.random()*Math.PI*2,r=22+Math.random()*27,x=Math.cos(a)*r,z=Math.sin(a)*r;
    if(Math.abs(x)<23 && Math.abs(z)<20) continue;
    tree(x,z,i%4===0);
  }
  for(let i=0;i<80;i++){
    const x=-48+Math.random()*96,z=-48+Math.random()*96;
    if(Math.abs(x)<24&&Math.abs(z)<20) continue;
    plant(x,z,i%3===0?'berry':'medicine');
  }
}

function buildCamp(){
  const g=new THREE.Group(); g.position.set(0,0,22); world.add(g);
  for(let i=0;i<8;i++){const a=i*Math.PI/4; const log=cyl(.2,2.1,mats.wood,Math.cos(a)*.8,.3,Math.sin(a)*.8,8,g); log.rotation.z=Math.PI/2; log.rotation.y=a;}
  const flame=cone(.7,1.5,mats.fire,0,1.1,0,6,g);
  const light=new THREE.PointLight(0xff8b32,2.5,12); light.position.y=2; g.add(light);
  g.userData={type:'campfire'}; state.camp=g; state.campLight=light;
  interactables.push(g);
}

function chest(x,z){
  const g=new THREE.Group(); g.position.set(x,.45,z); world.add(g);
  box(1.4,.8,.9,new THREE.MeshLambertMaterial({color:0x6d3515}),0,0,0,g);
  box(1.5,.12,1.0,new THREE.MeshLambertMaterial({color:0x9b5524}),0,.46,0,g);
  g.userData={type:'chest',opened:false}; interactables.push(g);
}

function buildShrine(){
  const g=new THREE.Group(); g.position.set(-35,.1,-35); world.add(g);
  box(6,.7,6,mats.stone,0,.35,0,g);
  const gem=cyl(.7,2.1,mats.green,0,1.8,0,6,g); gem.visible=false;
  g.userData={type:'shrine',gem};
  interactables.push(g);
}

function spawnEnemy(type){
  const g=new THREE.Group();
  const a=Math.random()*Math.PI*2,r=15+Math.random()*18;
  g.position.set(Math.cos(a)*r,0,Math.sin(a)*r);
  world.add(g);
  if(type==='bull'){
    cyl(1.1,1.8,new THREE.MeshLambertMaterial({color:0x2a2420}),0,1,0,8,g);
    cone(.25,.8,new THREE.MeshLambertMaterial({color:0xd4c5a2}),-.75,1.9,0,5,g).rotation.z=-.7;
    cone(.25,.8,new THREE.MeshLambertMaterial({color:0xd4c5a2}),.75,1.9,0,5,g).rotation.z=.7;
    g.userData={type:'enemy',enemyType:'bull',hp:80,speed:1.5,damage:18};
  }else{
    cyl(.45,1.7,new THREE.MeshLambertMaterial({color:0xbbbdb5}),0,1,0,7,g);
    cyl(.18,.8,new THREE.MeshLambertMaterial({color:0x292b2a}),-.55,.8,0,6,g).rotation.z=.8;
    cyl(.18,.8,new THREE.MeshLambertMaterial({color:0x292b2a}),.55,.8,0,6,g).rotation.z=-.8;
    g.userData={type:'enemy',enemyType:'skeleton',hp:30,speed:2.1,damage:8};
  }
  enemies.push(g);
}

function buildBoss(){
  const g=new THREE.Group(); g.position.set(-35,0,-30); world.add(g);
  cyl(1.5,3.5,new THREE.MeshLambertMaterial({color:0x101513}),0,2,0,8,g);
  cone(1.2,2.4,new THREE.MeshLambertMaterial({color:0x192b22}),0,5,0,8,g);
  const eye=new THREE.Mesh(new THREE.SphereGeometry(.12,8,8),mats.green); eye.position.set(0,5.3,.9); g.add(eye);
  g.userData={type:'boss',hp:300,speed:1.1,damage:25};
  enemies.push(g); state.bossEntity=g;
  showMessage('THE EMERALD GUARDIAN HAS AWAKENED.',4);
}

function loadOptionalAssets(){
  // GitHub Pages cannot load .blend directly. If you export these source files to GLB,
  // drop them into /assets with the names below and this loader will place them automatically.
  const assets=[
    ['trees.glb','trees',new THREE.Vector3(1,1,1)],
    ['bushes.glb','bushes',new THREE.Vector3(1,1,1)],
    ['wood-logs.glb','logs',new THREE.Vector3(1,1,1)],
    ['body.glb','body',new THREE.Vector3(1,1,1)],
    ['grass.glb','grass',new THREE.Vector3(1,1,1)]
  ];
  for(const [file,key,scale] of assets){
    loader.load('./assets/'+file,(gltf)=>{
      const root=gltf.scene; root.scale.copy(scale); root.traverse(o=>{if(o.isMesh){o.castShadow=false;o.receiveShadow=false}});
      root.visible=false; scene.add(root); window.__VEIL_ASSETS=window.__VEIL_ASSETS||{}; window.__VEIL_ASSETS[key]=root;
    },undefined,()=>{});
  }
}

function setupInput(){
  const start=document.querySelector('#start');
  document.querySelector('#startBtn').onclick=()=>{state.started=true;start.classList.add('hidden');document.body.requestPointerLock?.();};
  addEventListener('keydown',e=>{
    if(e.code==='KeyW') state.move.y=1;
    if(e.code==='KeyS') state.move.y=-1;
    if(e.code==='KeyA') state.move.x=-1;
    if(e.code==='KeyD') state.move.x=1;
    if(e.code==='ShiftLeft') state.sprinting=true;
    if(e.code==='KeyE') interact();
  });
  addEventListener('keyup',e=>{
    if(['KeyW','KeyS'].includes(e.code)) state.move.y=0;
    if(['KeyA','KeyD'].includes(e.code)) state.move.x=0;
    if(e.code==='ShiftLeft') state.sprinting=false;
  });
  addEventListener('mousemove',e=>{
    if(document.pointerLockElement) look(e.movementX,e.movementY);
  });
  addEventListener('mousedown',()=>{if(state.started) chopOrAttack()});
  document.querySelector('#attackBtn').onclick=chopOrAttack;
  document.querySelector('#interactBtn').onclick=interact;
  const stick=document.querySelector('#stick'),knob=document.querySelector('#knob');
  let sid=null,center=new THREE.Vector2();
  stick.addEventListener('pointerdown',e=>{sid=e.pointerId;center.set(100,100);stick.setPointerCapture(sid)});
  stick.addEventListener('pointermove',e=>{
    if(e.pointerId!==sid)return;
    const r=stick.getBoundingClientRect(),dx=e.clientX-(r.left+75),dy=e.clientY-(r.top+75);
    const v=new THREE.Vector2(dx,dy).multiplyScalar(1/60); if(v.length()>1)v.normalize();
    state.move.set(v.x,-v.y); knob.style.transform=`translate(${v.x*45}px,${v.y*45}px)`;
  });
  const end=()=>{sid=null;state.move.set(0,0);knob.style.transform=''};
  stick.addEventListener('pointerup',end);stick.addEventListener('pointercancel',end);
  const lookPad=document.querySelector('#lookPad');let lid=null,last=new THREE.Vector2();
  lookPad.addEventListener('pointerdown',e=>{lid=e.pointerId;last.set(e.clientX,e.clientY);lookPad.setPointerCapture(lid)});
  lookPad.addEventListener('pointermove',e=>{if(e.pointerId!==lid)return;look(e.clientX-last.x,e.clientY-last.y);last.set(e.clientX,e.clientY)});
  const lend=()=>lid=null;lookPad.addEventListener('pointerup',lend);lookPad.addEventListener('pointercancel',lend);
  document.querySelector('#sprintBtn').addEventListener('pointerdown',()=>state.sprinting=true);
  document.querySelector('#sprintBtn').addEventListener('pointerup',()=>state.sprinting=false);
}
function look(dx,dy){state.yaw-=dx*.002;state.pitch-=dy*.002;state.pitch=Math.max(-1.35,Math.min(1.25,state.pitch));}
function interact(){
  raycaster.setFromCamera({x:0,y:0},camera);
  const hits=raycaster.intersectObjects(interactables,true);
  if(!hits.length)return;
  let o=hits[0].object; while(o.parent && !o.userData.type)o=o.parent;
  if(!o.userData.type)return;
  const d=camera.position.distanceTo(o.getWorldPosition(new THREE.Vector3()));
  if(d>5)return;
  if(o.userData.type==='chest'&&!o.userData.opened){o.userData.opened=true;state.wood+=5;if(Math.random()<.35){state.redAxe=true;showMessage('RED AXE FOUND — FASTER CHOPPING',3)}else showMessage('CHEST LOOTED: +5 WOOD',2);o.rotation.x=-.35;}
  if(o.userData.type==='campfire'&&state.wood>=[0,8,16,28,44,64][state.campLevel]&&state.campLevel<6){const cost=[0,8,16,28,44,64][state.campLevel];state.wood-=cost;state.campLevel++;state.campLight.distance=12+state.campLevel*3;showMessage('CAMPFIRE UPGRADED TO LEVEL '+state.campLevel,3);}
  if(o.userData.type==='berry'){state.berries+=2;showMessage('+2 BERRIES',1);o.visible=false;}
  if(o.userData.type==='medicine'){state.medicine++;state.hp=Math.min(100,state.hp+12);showMessage('MEDICINAL PLANT COLLECTED',1);o.visible=false;}
  if(o.userData.type==='shrine'&&state.day>=50){if(!state.boss){state.boss=true;buildBoss()}else if(!state.emerald){state.emerald=true;o.userData.gem.visible=true;showMessage('EMERALD CLAIMED — ESCAPE!',4)}}
}
function chopOrAttack(){
  raycaster.setFromCamera({x:0,y:0},camera);
  const hits=raycaster.intersectObjects(interactables.concat(enemies),true);
  if(!hits.length)return;
  let o=hits[0].object;while(o.parent&&!o.userData.type)o=o.parent;
  if(camera.position.distanceTo(o.getWorldPosition(new THREE.Vector3()))>4)return;
  if(o.userData.type==='tree'){o.userData.hp--;state.wood+=state.redAxe?2:1;if(o.userData.hp<=0){o.visible=false;showMessage('TREE CUT — WOOD COLLECTED',1)}}
  if(o.userData.type==='enemy'||o.userData.type==='boss'){o.userData.hp-=state.redAxe?30:15;if(o.userData.hp<=0){o.visible=false;const i=enemies.indexOf(o);if(i>=0)enemies.splice(i,1);if(o.userData.type==='boss'){state.emerald=true;state.boss=false;state.messageTimer=4;showMessage('THE GUARDIAN FALLS — TAKE THE EMERALD',4)}}}
}

function updatePlayer(dt){
  const dir=new THREE.Vector3(state.move.x,0,-state.move.y);
  if(dir.length()>1)dir.normalize();
  const speed=state.sprinting?state.speed*1.55:state.speed;
  const sin=Math.sin(state.yaw),cos=Math.cos(state.yaw);
  const dx=dir.x*cos-dir.z*sin,dz=dir.x*sin+dir.z*cos;
  camera.position.x+=dx*speed*dt;camera.position.z+=dz*speed*dt;
  camera.position.x=THREE.MathUtils.clamp(camera.position.x,-49,49);camera.position.z=THREE.MathUtils.clamp(camera.position.z,-49,49);
  camera.position.y=1.65;
  camera.rotation.order='YXZ';camera.rotation.y=state.yaw;camera.rotation.x=state.pitch;
}

function updateWorld(dt){
  state.time+=dt*24/95;
  if(state.time>=24){state.time-=24;state.day++;if(state.day>=50){state.day=50;showMessage('DAY 50 — THE EMERALD SHRINE IS NOW ACTIVE.',5)}}
  state.night=state.time<6||state.time>=19;
  state.hunger=Math.max(0,state.hunger-dt*.012);state.thirst=Math.max(0,state.thirst-dt*.022);
  if(state.hunger===0||state.thirst===0)state.hp=Math.max(0,state.hp-dt*1.2);
  const daylight=Math.max(0,Math.sin((state.time-6)/24*Math.PI*2)*.5+.5);
  scene.background.setHSL(.55,.18,.16+.34*daylight);
  scene.fog.color.copy(scene.background);
  state.campLight.intensity=state.night?3.5:1.3;
  if(state.night && enemies.filter(e=>e.visible).length<5 && Math.random()<dt*.07)spawnEnemy(Math.random()<.12?'bull':'skeleton');
  if(!state.night) enemies.forEach(e=>e.visible=false);
  if(state.messageTimer>0){state.messageTimer-=dt;if(state.messageTimer<=0)document.querySelector('#message').textContent=''}
}

function updateEnemies(dt){
  for(const e of enemies){
    if(!e.visible)continue;
    const target=new THREE.Vector3(camera.position.x,0,camera.position.z);
    const p=e.position.clone();p.y=0;let d=p.distanceTo(target);
    const safe=state.campLevel*3.5+10;
    if(e.userData.type==='enemy'&&e.position.distanceTo(state.camp.position)<safe){e.position.add(p.sub(state.camp.position).normalize().multiplyScalar(dt*.8));continue;}
    if(d>1.8){const v=target.sub(e.position);v.y=0;v.normalize();e.position.add(v.multiplyScalar(e.userData.speed*dt));e.lookAt(camera.position.x,e.position.y,camera.position.z)}
    else state.hp=Math.max(0,state.hp-e.userData.damage*dt*.35);
  }
}

function updateHUD(){
  const q=id=>document.querySelector(id);
  q('#day').textContent=`DAY ${String(state.day).padStart(2,'0')}`;
  const h=Math.floor(state.time),m=Math.floor((state.time-h)*60);q('#clock').textContent=`${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`;
  q('#weather').textContent=state.night?'NIGHT — DANGER':'CLEAR';
  q('#hp').style.width=state.hp+'%';q('#hunger').style.width=state.hunger+'%';q('#thirst').style.width=state.thirst+'%';
  q('#wood').textContent=state.wood;q('#berries').textContent=state.berries;q('#medicine').textContent=state.medicine;q('#campLevel').textContent=state.campLevel;
  if(state.emerald&&!state.win){state.win=true;q('#win').classList.remove('hidden')}
}

function animate(){
  requestAnimationFrame(animate);
  const dt=Math.min(clock.getDelta(),.05);
  if(state.started&&!state.win){updatePlayer(dt);updateWorld(dt);updateEnemies(dt);updateHUD()}
  renderer.render(scene,camera);
}

buildIsland();buildTown();buildForest();buildCamp();buildShrine();
for(let i=0;i<10;i++)chest(-42+Math.random()*84,-42+Math.random()*84);
setupInput();loadOptionalAssets();animate();
addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);});
