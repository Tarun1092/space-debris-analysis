import json
import math
import os
import numpy as np
import pyvista as pv

def main():
    data_path = r"C:\Users\Tarun Vignesh B S\.gemini\antigravity\scratch\space-debris-analytics\data\satcat_processed.json"
    if not os.path.exists(data_path):
        print(f"Error: Catalog file not found at {data_path}")
        return

    with open(data_path, "r") as f:
        catalog = json.load(f)

    print(f"Loaded {len(catalog)} objects from catalog.")

    # Initialize PyVista Plotter
    plotter = pv.Plotter(window_size=[1280, 800], title="OrbitalGuard AI - PyVista 3D Earth Debris Visualizer")
    plotter.set_background("#070913")

    # Load PyVista's built-in Earth surface texture
    print("Loading PyVista built-in Earth surface texture (Option 1)...")
    try:
        earth_texture = pv.examples.load_globe_texture()
        earth_sphere = pv.Sphere(radius=1.0, theta_resolution=180, phi_resolution=180)
        plotter.add_mesh(earth_sphere, texture=earth_texture, smooth_shading=True)
        print("Successfully applied PyVista Earth texture!")
    except Exception as e:
        print(f"Texture loading fallback: {e}")
        earth_sphere = pv.Sphere(radius=1.0, theta_resolution=90, phi_resolution=90)
        plotter.add_mesh(earth_sphere, color="#1a3d80", show_edges=True, edge_color="#00e5ff", opacity=0.9)

    # Convert Keplerian elements to 3D Cartesian coordinates relative to Earth radius = 1.0
    EARTH_RADIUS_KM = 6371.0
    payload_coords = []
    debris_coords = []
    rocket_coords = []

    for item in catalog:
        mean_alt = (item["perigee_km"] + item["apogee_km"]) / 2.0
        r_units = 1.0 + (mean_alt / EARTH_RADIUS_KM)
        
        inc_rad = math.radians(item["inclination_deg"])
        raan_rad = math.radians(item["raan_deg"])
        argp_rad = math.radians(item["arg_perigee_deg"])
        nu = math.radians(item["mean_anomaly_deg"])
        u = argp_rad + nu
        
        x_orb = r_units * math.cos(u)
        y_orb = r_units * math.sin(u)
        
        X = x_orb * math.cos(raan_rad) - y_orb * math.sin(raan_rad) * math.cos(inc_rad)
        Y = x_orb * math.sin(raan_rad) + y_orb * math.cos(raan_rad) * math.cos(inc_rad)
        Z = y_orb * math.sin(inc_rad)
        
        pos = [X, Z, Y]
        if item["object_type"] == "PAYLOAD":
            payload_coords.append(pos)
        elif item["object_type"] == "DEBRIS":
            debris_coords.append(pos)
        else:
            rocket_coords.append(pos)

    # Add 3D Point Clouds around Earth Globe
    if payload_coords:
        p_cloud = pv.PolyData(np.array(payload_coords))
        plotter.add_mesh(p_cloud, color="#00e5ff", point_size=5, render_points_as_spheres=True, label=f"Active Satellites ({len(payload_coords)})")

    if debris_coords:
        d_cloud = pv.PolyData(np.array(debris_coords))
        plotter.add_mesh(d_cloud, color="#ff2a6d", point_size=4, render_points_as_spheres=True, label=f"Space Debris ({len(debris_coords)})")

    if rocket_coords:
        r_cloud = pv.PolyData(np.array(rocket_coords))
        plotter.add_mesh(r_cloud, color="#ffb703", point_size=5, render_points_as_spheres=True, label=f"Spent Rocket Bodies ({len(rocket_coords)})")

    plotter.add_legend(bcolor="rgba(14, 18, 36, 0.85)", border=True)
    plotter.add_text("OrbitalGuard AI: PyVista 3D Earth Space Debris Visualizer", font_size=12, color="#00e5ff", position="upper_left")

    print("Launching PyVista 3D Interactive Window...")
    plotter.show()

if __name__ == "__main__":
    main()
