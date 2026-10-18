/* ==========================================================================
   OrbitalGuard AI - 4K Photographic NASA Earth 3D Engine (app.js)
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
    // Application State
    const state = {
        catalog: [],
        stats: null,
        filteredCatalog: [],
        
        // Viewport Controls & Toggles
        autoRotate: true,
        showOrbits: true,
        showShells: true,
        showRings: true,
        showClouds: true,
        activeFilter: 'ALL',
        maxAltitude: 36000,
        
        // Three.js Core Objects
        scene: null,
        camera: null,
        renderer: null,
        earthGroup: null,
        earthMesh: null,
        cloudMesh: null,
        atmosMesh: null,
        leoShellMesh: null,
        geoRingMesh: null,
        debrisRingGroup: null,
        pointCloud: null,
        orbitLineGroup: null,
        
        // Polar Camera Rotations
        rotX: 0.2,
        rotY: 0.8,
        zoomDist: 20,

        EARTH_RADIUS: 5.0, // 6,371 km mapped to 5.0 3D units
        KM_TO_UNITS: 5.0 / 6371.0
    };

    // Main Init
    init();

    async function init() {
        initBackgroundStarfield();
        setupTabNavigation();

        try {
            await loadDatasets();
        } catch (err) {
            console.warn("Dataset fetch warning, generating runtime fallback dataset:", err);
            generateFallbackDatasets();
        }

        updateHeaderStats();
        init3DScene();
        initInspectorControls();
        renderAnalyticsCharts();

        window.addEventListener('resize', onWindowResize);
    }

    // ----------------------------------------------------------------------
    // 1. Data Ingestion & Dataset Fallback
    // ----------------------------------------------------------------------
    async function loadDatasets() {
        const [catRes, statRes] = await Promise.all([
            fetch('data/satcat_processed.json'),
            fetch('data/orbit_stats.json')
        ]);

        state.catalog = await catRes.json();
        state.stats = await statRes.json();
        state.filteredCatalog = [...state.catalog];
    }

    function generateFallbackDatasets() {
        state.catalog = [];
        const countries = ["USA", "IND", "PRC", "CIS", "ESA"];
        const types = ["PAYLOAD", "DEBRIS", "ROCKET BODY"];
        
        for (let i = 1; i <= 3500; i++) {
            const t = types[i % 3];
            const c = countries[i % 5];
            const alt = t === "PAYLOAD" ? 400 + (i % 600) : 250 + (i * 7 % 1400);
            state.catalog.push({
                norad_id: 50000 + i,
                name: `${c} ${t} #${i}`,
                object_type: t,
                country: c,
                orbit_type: alt < 2000 ? "LEO" : "GEO",
                perigee_km: alt,
                apogee_km: alt + (i % 50),
                inclination_deg: (i * 13.7) % 99,
                raan_deg: (i * 27.3) % 360,
                arg_perigee_deg: (i * 41.1) % 360,
                mean_anomaly_deg: (i * 53.2) % 360,
                mean_motion_rev_day: 15.2,
                velocity_km_s: 7.6,
                period_min: 94.5,
                rcs_size: "MEDIUM",
                launch_date: "2020-01-01",
                bstar_drag: 0.0001
            });
        }
        state.filteredCatalog = [...state.catalog];
        state.stats = {
            total_tracked_objects: 3500,
            active_satellites: 710,
            tracked_debris_pieces: 2275,
            by_object_type: { PAYLOAD: 710, DEBRIS: 2275, "ROCKET BODY": 515 },
            by_country: { USA: 1200, IND: 350, PRC: 900, CIS: 700, ESA: 350 },
            leo_altitude_distribution: {
                bins: ["200-300", "300-400", "400-500", "500-600", "600-700", "700-800", "800-900", "900-1000"],
                counts: [120, 310, 450, 680, 520, 890, 740, 290]
            }
        };
    }

    function updateHeaderStats() {
        if (!state.stats) return;
        const totalEl = document.getElementById('nav-stat-total');
        const debrisEl = document.getElementById('nav-stat-debris');
        const payloadsEl = document.getElementById('nav-stat-payloads');

        if (totalEl) totalEl.innerText = (state.stats.total_tracked_objects || 3500).toLocaleString();
        if (debrisEl) debrisEl.innerText = (state.stats.tracked_debris_pieces || 2275).toLocaleString();
        if (payloadsEl) payloadsEl.innerText = (state.stats.active_satellites || 710).toLocaleString();
    }

    // ----------------------------------------------------------------------
    // 2. Photographic 4K Earth WebGL Engine
    // ----------------------------------------------------------------------
    function init3DScene() {
        const container = document.getElementById('canvas-3d');
        if (!container) return;

        const width = container.clientWidth || (window.innerWidth - 300);
        const height = container.clientHeight || (window.innerHeight - 64);

        state.scene = new THREE.Scene();

        state.camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
        state.camera.position.set(0, 5, state.zoomDist);

        state.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance" });
        state.renderer.setSize(width, height);
        state.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

        container.innerHTML = '';
        container.appendChild(state.renderer.domElement);

        // Realistic Solar & Atmospheric Lighting
        const ambientLight = new THREE.AmbientLight(0xffffff, 1.1);
        state.scene.add(ambientLight);

        // Sun Directional Light
        const sunLight = new THREE.DirectionalLight(0xffffff, 2.0);
        sunLight.position.set(30, 20, 30);
        state.scene.add(sunLight);

        // Earthshine Blue Fill Light
        const earthshine = new THREE.DirectionalLight(0x0066ff, 0.5);
        earthshine.position.set(-30, -15, -30);
        state.scene.add(earthshine);

        // Earth Group with 23.44 Degree Axial Tilt
        state.earthGroup = new THREE.Group();
        state.earthGroup.rotation.z = (23.44 * Math.PI) / 180.0;
        state.scene.add(state.earthGroup);

        // Trajectories Line Group
        state.orbitLineGroup = new THREE.Group();
        state.scene.add(state.orbitLineGroup);

        // Build 4K Photographic Earth Mesh
        createPhotographicEarthMesh();
        createAtmosphericClouds();
        createAtmosphericRayleighGlow();

        // Build Orbital Shells & Debris Rings
        createOrbitalShells();
        createDebrisRings();

        // Build Debris Point Cloud
        createOrbitalPointCloud();

        // Controls
        setupMouseDragControls(container);

        // Start Animation Loop
        animate();
    }

    function createPhotographicEarthMesh() {
        const geometry = new THREE.SphereGeometry(state.EARTH_RADIUS, 64, 64);
        
        // Load actual 4K NASA Earth texture map
        const textureLoader = new THREE.TextureLoader();
        
        const material = new THREE.MeshStandardMaterial({
            roughness: 0.45,
            metalness: 0.1,
            emissive: new THREE.Color(0x0a1226),
            emissiveIntensity: 0.25
        });

        textureLoader.load(
            'data/earth_texture.jpg',
            (texture) => {
                material.map = texture;
                material.needsUpdate = true;
                console.log("Loaded authentic 4K NASA Earth surface texture map!");
            },
            undefined,
            (err) => {
                console.warn("Falling back to procedural high-res texture map:", err);
                material.map = generateProceduralEarthTexture();
                material.needsUpdate = true;
            }
        );

        state.earthMesh = new THREE.Mesh(geometry, material);
        state.earthGroup.add(state.earthMesh);
    }

    function generateProceduralEarthTexture() {
        const canvas = document.createElement('canvas');
        canvas.width = 2048; canvas.height = 1024;
        const ctx = canvas.getContext('2d');

        const oceanGrad = ctx.createLinearGradient(0, 0, 0, canvas.height);
        oceanGrad.addColorStop(0, '#040b1e');
        oceanGrad.addColorStop(0.5, '#0a2356');
        oceanGrad.addColorStop(1, '#040b1e');
        ctx.fillStyle = oceanGrad;
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        ctx.fillStyle = '#1c4294';
        ctx.beginPath(); ctx.ellipse(260, 210, 95, 135, 0.2, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.ellipse(650, 180, 165, 115, 0, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.ellipse(680, 330, 85, 95, 0, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.ellipse(860, 360, 55, 55, 0, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.ellipse(1440, 545, 30, 35, 0.1, 0, Math.PI * 2); ctx.fill();

        return new THREE.CanvasTexture(canvas);
    }

    function createAtmosphericClouds() {
        const geometry = new THREE.SphereGeometry(state.EARTH_RADIUS * 1.02, 64, 64);
        
        const canvas = document.createElement('canvas');
        canvas.width = 1024; canvas.height = 512;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = 'rgba(255, 255, 255, 0)';
        ctx.fillRect(0, 0, 1024, 512);

        ctx.fillStyle = 'rgba(255, 255, 255, 0.4)';
        for (let i = 0; i < 70; i++) {
            const cx = Math.random() * 1024;
            const cy = 60 + Math.random() * 392;
            const rx = 30 + Math.random() * 80;
            const ry = 15 + Math.random() * 35;
            ctx.beginPath(); ctx.ellipse(cx, cy, rx, ry, Math.random(), 0, Math.PI * 2); ctx.fill();
        }

        const texture = new THREE.CanvasTexture(canvas);
        texture.needsUpdate = true;

        const material = new THREE.MeshStandardMaterial({
            map: texture,
            transparent: true,
            opacity: 0.4,
            depthWrite: false
        });

        state.cloudMesh = new THREE.Mesh(geometry, material);
        state.earthGroup.add(state.cloudMesh);
    }

    function createAtmosphericRayleighGlow() {
        const geometry = new THREE.SphereGeometry(state.EARTH_RADIUS * 1.08, 64, 64);
        
        const atmosMat = new THREE.ShaderMaterial({
            vertexShader: `
                varying vec3 vNormal;
                void main() {
                    vNormal = normalize(normalMatrix * normal);
                    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
                }
            `,
            fragmentShader: `
                varying vec3 vNormal;
                void main() {
                    float intensity = pow(0.65 - dot(vNormal, vec3(0, 0, 1.0)), 2.8);
                    gl_FragColor = vec4(0.0, 0.85, 1.0, 1.0) * intensity * 0.85;
                }
            `,
            blending: THREE.AdditiveBlending,
            side: THREE.BackSide,
            transparent: true
        });

        state.atmosMesh = new THREE.Mesh(geometry, atmosMat);
        state.scene.add(state.atmosMesh);
    }

    function createOrbitalShells() {
        const leoAlt = 2000.0;
        const leoRadius = state.EARTH_RADIUS + (leoAlt * state.KM_TO_UNITS);
        const leoGeo = new THREE.SphereGeometry(leoRadius, 32, 32);
        const leoMat = new THREE.MeshBasicMaterial({
            color: 0x00e5ff,
            wireframe: true,
            transparent: true,
            opacity: 0.08
        });
        state.leoShellMesh = new THREE.Mesh(leoGeo, leoMat);
        state.scene.add(state.leoShellMesh);

        const geoAlt = 35786.0;
        const geoRadius = state.EARTH_RADIUS + (geoAlt * state.KM_TO_UNITS);
        
        const ringPoints = [];
        for (let i = 0; i <= 128; i++) {
            const theta = (i / 128) * Math.PI * 2;
            ringPoints.push(new THREE.Vector3(geoRadius * Math.cos(theta), 0, geoRadius * Math.sin(theta)));
        }
        const geoLineGeo = new THREE.BufferGeometry().setFromPoints(ringPoints);
        const geoLineMat = new THREE.LineBasicMaterial({
            color: 0xffd700,
            transparent: true,
            opacity: 0.5,
            linewidth: 2
        });
        state.geoRingMesh = new THREE.Line(geoLineGeo, geoLineMat);
        state.scene.add(state.geoRingMesh);
    }

    function createDebrisRings() {
        state.debrisRingGroup = new THREE.Group();

        // 1. Fengyun-1C Breakup Ring
        const fyRadius = state.EARTH_RADIUS + (865.0 * state.KM_TO_UNITS);
        const fyPoints = [];
        const incRad = (98.8 * Math.PI) / 180.0;
        for (let i = 0; i <= 128; i++) {
            const u = (i / 128) * Math.PI * 2;
            const x = fyRadius * Math.cos(u);
            const y = fyRadius * Math.sin(u) * Math.cos(incRad);
            const z = fyRadius * Math.sin(u) * Math.sin(incRad);
            fyPoints.push(new THREE.Vector3(x, z, y));
        }
        const fyGeo = new THREE.BufferGeometry().setFromPoints(fyPoints);
        const fyMat = new THREE.LineDashedMaterial({ color: 0xff2a6d, dashSize: 0.3, gapSize: 0.2, transparent: true, opacity: 0.75 });
        const fyLine = new THREE.Line(fyGeo, fyMat);
        fyLine.computeLineDistances();
        state.debrisRingGroup.add(fyLine);

        // 2. Iridium 33 - Kosmos 2251 Collision Ring
        const ikRadius = state.EARTH_RADIUS + (789.0 * state.KM_TO_UNITS);
        const ikPoints = [];
        const ikIncRad = (74.0 * Math.PI) / 180.0;
        for (let i = 0; i <= 128; i++) {
            const u = (i / 128) * Math.PI * 2;
            const x = ikRadius * Math.cos(u);
            const y = ikRadius * Math.sin(u) * Math.cos(ikIncRad);
            const z = ikRadius * Math.sin(u) * Math.sin(ikIncRad);
            ikPoints.push(new THREE.Vector3(x, z, y));
        }
        const ikGeo = new THREE.BufferGeometry().setFromPoints(ikPoints);
        const ikMat = new THREE.LineDashedMaterial({ color: 0xffb703, dashSize: 0.3, gapSize: 0.2, transparent: true, opacity: 0.75 });
        const ikLine = new THREE.Line(ikGeo, ikMat);
        ikLine.computeLineDistances();
        state.debrisRingGroup.add(ikLine);

        state.scene.add(state.debrisRingGroup);
    }

    function getECIPosition(item, timeFactor = 0) {
        const meanAlt = (item.perigee_km + item.apogee_km) / 2.0;
        const r_km = 6371.0 + meanAlt;
        const r_units = r_km * state.KM_TO_UNITS;

        const inc_rad = (item.inclination_deg * Math.PI) / 180.0;
        const raan_rad = (item.raan_deg * Math.PI) / 180.0;
        const argp_rad = (item.arg_perigee_deg * Math.PI) / 180.0;
        
        const n_rev_sec = (item.mean_motion_rev_day || 15.0) / 86400.0;
        const nu = (item.mean_anomaly_deg * Math.PI) / 180.0 + (timeFactor * n_rev_sec * 2.0 * Math.PI);

        const u = argp_rad + nu;

        const x_orb = r_units * Math.cos(u);
        const y_orb = r_units * Math.sin(u);

        const X = x_orb * Math.cos(raan_rad) - y_orb * Math.sin(raan_rad) * Math.cos(inc_rad);
        const Y = x_orb * Math.sin(raan_rad) + y_orb * Math.cos(raan_rad) * Math.cos(inc_rad);
        const Z = y_orb * Math.sin(inc_rad);

        return new THREE.Vector3(X, Z, Y);
    }

    function createOrbitalPointCloud() {
        if (state.pointCloud) state.scene.remove(state.pointCloud);

        const count = state.filteredCatalog.length;
        if (count === 0) return;

        const positions = new Float32Array(count * 3);
        const colors = new Float32Array(count * 3);

        state.filteredCatalog.forEach((item, idx) => {
            const pos = getECIPosition(item, 0);
            positions[idx * 3] = pos.x;
            positions[idx * 3 + 1] = pos.y;
            positions[idx * 3 + 2] = pos.z;

            let r = 0.0, g = 0.9, b = 1.0;
            if (item.country === 'IND') {
                r = 1.0; g = 0.6; b = 0.2;
            } else if (item.object_type === 'DEBRIS') {
                r = 1.0; g = 0.16; b = 0.43;
            } else if (item.object_type === 'ROCKET BODY') {
                r = 1.0; g = 0.72; b = 0.01;
            }

            colors[idx * 3] = r;
            colors[idx * 3 + 1] = g;
            colors[idx * 3 + 2] = b;
        });

        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

        const canvas = document.createElement('canvas');
        canvas.width = 16; canvas.height = 16;
        const ctx = canvas.getContext('2d');
        const grad = ctx.createRadialGradient(8, 8, 0, 8, 8, 8);
        grad.addColorStop(0, 'rgba(255,255,255,1)');
        grad.addColorStop(0.4, 'rgba(255,255,255,0.9)');
        grad.addColorStop(1, 'rgba(255,255,255,0)');
        ctx.fillStyle = grad; ctx.fillRect(0, 0, 16, 16);

        const pTex = new THREE.CanvasTexture(canvas);

        const material = new THREE.PointsMaterial({
            size: 0.38,
            vertexColors: true,
            map: pTex,
            transparent: true,
            opacity: 0.95,
            depthWrite: false
        });

        state.pointCloud = new THREE.Points(geometry, material);
        state.scene.add(state.pointCloud);
    }

    function updateOrbitalPositions(timeSec) {
        if (!state.pointCloud) return;
        const positions = state.pointCloud.geometry.attributes.position.array;

        state.filteredCatalog.forEach((item, idx) => {
            const pos = getECIPosition(item, timeSec);
            positions[idx * 3] = pos.x;
            positions[idx * 3 + 1] = pos.y;
            positions[idx * 3 + 2] = pos.z;
        });

        state.pointCloud.geometry.attributes.position.needsUpdate = true;
    }

    function setupMouseDragControls(domElement) {
        let isDragging = false;
        let previousMousePosition = { x: 0, y: 0 };

        domElement.addEventListener('mousedown', (e) => {
            isDragging = true;
            previousMousePosition = { x: e.clientX, y: e.clientY };
        });

        domElement.addEventListener('mousemove', (e) => {
            if (!isDragging) return;
            const deltaMove = {
                x: e.clientX - previousMousePosition.x,
                y: e.clientY - previousMousePosition.y
            };

            state.rotY += deltaMove.x * 0.005;
            state.rotX += deltaMove.y * 0.005;

            state.rotX = Math.max(-Math.PI / 2.2, Math.min(Math.PI / 2.2, state.rotX));

            previousMousePosition = { x: e.clientX, y: e.clientY };
        });

        window.addEventListener('mouseup', () => { isDragging = false; });

        domElement.addEventListener('wheel', (e) => {
            e.preventDefault();
            state.zoomDist += e.deltaY * 0.015;
            state.zoomDist = Math.max(6.5, Math.min(65.0, state.zoomDist));
        }, { passive: false });
    }

    function animate(timestamp = 0) {
        requestAnimationFrame(animate);

        const timeSec = timestamp * 0.001;

        if (state.autoRotate && state.earthGroup) {
            state.earthGroup.rotation.y += 0.0015;
        }

        if (state.cloudMesh) {
            state.cloudMesh.rotation.y += 0.0006;
        }

        state.camera.position.x = state.zoomDist * Math.sin(state.rotY) * Math.cos(state.rotX);
        state.camera.position.y = state.zoomDist * Math.sin(state.rotX);
        state.camera.position.z = state.zoomDist * Math.cos(state.rotY) * Math.cos(state.rotX);
        state.camera.lookAt(0, 0, 0);

        updateOrbitalPositions(timeSec);

        state.renderer.render(state.scene, state.camera);
    }

    function onWindowResize() {
        const container = document.getElementById('canvas-3d');
        if (!container || !state.renderer || !state.camera) return;

        const width = container.clientWidth || (window.innerWidth - 300);
        const height = container.clientHeight || (window.innerHeight - 64);

        state.camera.aspect = width / height;
        state.camera.updateProjectionMatrix();
        state.renderer.setSize(width, height);
    }

    function setupTabNavigation() {
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const targetTab = e.currentTarget.getAttribute('data-tab');
                document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
                document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
                
                e.currentTarget.classList.add('active');
                document.getElementById(targetTab).classList.add('active');

                if (targetTab === 'tab-3d') setTimeout(onWindowResize, 50);
            });
        });
    }

    function initInspectorControls() {
        const btnRotate = document.getElementById('btn-toggle-rotation');
        if (btnRotate) {
            btnRotate.addEventListener('click', () => {
                state.autoRotate = !state.autoRotate;
                btnRotate.classList.toggle('active', state.autoRotate);
                btnRotate.innerHTML = `<i class="fa-solid fa-arrows-rotate"></i> Auto Rotation: ${state.autoRotate ? 'ON' : 'OFF'}`;
            });
        }

        const btnReset = document.getElementById('btn-reset-view');
        if (btnReset) {
            btnReset.addEventListener('click', () => {
                state.rotX = 0.2;
                state.rotY = 0.8;
                state.zoomDist = 20;
            });
        }

        const btnOrbits = document.getElementById('btn-toggle-orbits');
        if (btnOrbits) {
            btnOrbits.addEventListener('click', () => {
                state.showOrbits = !state.showOrbits;
                btnOrbits.classList.toggle('active', state.showOrbits);
            });
        }

        const btnShells = document.getElementById('btn-toggle-shells');
        if (btnShells) {
            btnShells.addEventListener('click', () => {
                state.showShells = !state.showShells;
                btnShells.classList.toggle('active', state.showShells);
                if (state.leoShellMesh) state.leoShellMesh.visible = state.showShells;
                if (state.geoRingMesh) state.geoRingMesh.visible = state.showShells;
                btnShells.innerHTML = `<i class="fa-solid fa-circle-nodes"></i> LEO/GEO Shells: ${state.showShells ? 'ON' : 'OFF'}`;
            });
        }

        const btnRings = document.getElementById('btn-toggle-rings');
        if (btnRings) {
            btnRings.addEventListener('click', () => {
                state.showRings = !state.showRings;
                btnRings.classList.toggle('active', state.showRings);
                if (state.debrisRingGroup) state.debrisRingGroup.visible = state.showRings;
                btnRings.innerHTML = `<i class="fa-solid fa-ring"></i> Debris Rings: ${state.showRings ? 'ON' : 'OFF'}`;
            });
        }

        const btnClouds = document.getElementById('btn-toggle-clouds');
        if (btnClouds) {
            btnClouds.addEventListener('click', () => {
                state.showClouds = !state.showClouds;
                btnClouds.classList.toggle('active', state.showClouds);
                if (state.cloudMesh) state.cloudMesh.visible = state.showClouds;
                btnClouds.innerHTML = `<i class="fa-solid fa-cloud"></i> Clouds: ${state.showClouds ? 'ON' : 'OFF'}`;
            });
        }

        document.querySelectorAll('.filter-chip').forEach(chip => {
            chip.addEventListener('click', (e) => {
                document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
                e.currentTarget.classList.add('active');
                state.activeFilter = e.currentTarget.getAttribute('data-filter');
                applyFilters();
            });
        });

        const altSlider = document.getElementById('alt-slider');
        const altLabel = document.getElementById('alt-val-label');
        if (altSlider) {
            altSlider.addEventListener('input', (e) => {
                state.maxAltitude = parseInt(e.target.value);
                altLabel.innerText = `200 km - ${state.maxAltitude.toLocaleString()} km`;
                applyFilters();
            });
        }
    }

    function applyFilters() {
        state.filteredCatalog = state.catalog.filter(item => {
            const matchesType = (state.activeFilter === 'ALL') || (item.object_type === state.activeFilter);
            const matchesAlt = (item.apogee_km <= state.maxAltitude);
            return matchesType && matchesAlt;
        });

        createOrbitalPointCloud();
    }

    function renderAnalyticsCharts() {
        if (typeof Chart === 'undefined' || !state.stats) return;

        const ctxAlt = document.getElementById('chart-altitude');
        if (ctxAlt) {
            new Chart(ctxAlt, {
                type: 'bar',
                data: {
                    labels: state.stats.leo_altitude_distribution.bins,
                    datasets: [{
                        label: 'Tracked Space Objects Count',
                        data: state.stats.leo_altitude_distribution.counts,
                        backgroundColor: 'rgba(0, 229, 255, 0.6)',
                        borderColor: '#00e5ff',
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: {
                        x: { ticks: { color: '#8e9bb4', font: { size: 10 } }, grid: { color: 'rgba(255,255,255,0.05)' } },
                        y: { ticks: { color: '#8e9bb4' }, grid: { color: 'rgba(255,255,255,0.05)' } }
                    }
                }
            });
        }

        const ctxType = document.getElementById('chart-type');
        if (ctxType) {
            new Chart(ctxType, {
                type: 'doughnut',
                data: {
                    labels: Object.keys(state.stats.by_object_type),
                    datasets: [{
                        data: Object.values(state.stats.by_object_type),
                        backgroundColor: ['#00e5ff', '#ff2a6d', '#ffb703', '#8e9bb4'],
                        borderWidth: 0
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { position: 'bottom', labels: { color: '#f0f4fc' } } }
                }
            });
        }

        const ctxCountry = document.getElementById('chart-country');
        if (ctxCountry) {
            new Chart(ctxCountry, {
                type: 'bar',
                data: {
                    labels: Object.keys(state.stats.by_country),
                    datasets: [{
                        label: 'Objects Ingested',
                        data: Object.values(state.stats.by_country),
                        backgroundColor: 'rgba(124, 77, 255, 0.7)',
                        borderColor: '#7c4dff',
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: {
                        x: { ticks: { color: '#8e9bb4' }, grid: { color: 'rgba(255,255,255,0.05)' } },
                        y: { ticks: { color: '#8e9bb4' }, grid: { color: 'rgba(255,255,255,0.05)' } }
                    }
                }
            });
        }
    }

    function initBackgroundStarfield() {
        const bgCanvas = document.getElementById('bg-canvas');
        if (!bgCanvas) return;
        const ctx = bgCanvas.getContext('2d');

        function resize() {
            bgCanvas.width = window.innerWidth;
            bgCanvas.height = window.innerHeight;
        }
        resize();
        window.addEventListener('resize', resize);

        const stars = Array.from({ length: 140 }, () => ({
            x: Math.random() * bgCanvas.width,
            y: Math.random() * bgCanvas.height,
            size: Math.random() * 1.4,
            alpha: Math.random()
        }));

        function drawStars() {
            ctx.clearRect(0, 0, bgCanvas.width, bgCanvas.height);
            stars.forEach(star => {
                ctx.fillStyle = `rgba(255, 255, 255, ${star.alpha})`;
                ctx.beginPath();
                ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
                ctx.fill();

                star.alpha += (Math.random() - 0.5) * 0.02;
                if (star.alpha < 0.2) star.alpha = 0.2;
                if (star.alpha > 0.9) star.alpha = 0.9;
            });
            requestAnimationFrame(drawStars);
        }
        drawStars();
    }
});
