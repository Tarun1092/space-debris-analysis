import json
import math
import os
import numpy as np
import plotly.graph_objects as go

def main():
    data_path = r"C:\Users\Tarun Vignesh B S\.gemini\antigravity\scratch\space-debris-analytics\data\satcat_processed.json"
    if not os.path.exists(data_path):
        print(f"Error: Catalog file not found at {data_path}")
        return

    with open(data_path, "r") as f:
        catalog = json.load(f)

    print(f"Loaded {len(catalog)} objects from catalog.")

    EARTH_RADIUS_KM = 6371.0

    # Separate coordinate vectors by type
    types = {"PAYLOAD": {"x": [], "y": [], "z": [], "hover": [], "color": "#00e5ff"},
             "DEBRIS": {"x": [], "y": [], "z": [], "hover": [], "color": "#ff2a6d"},
             "ROCKET BODY": {"x": [], "y": [], "z": [], "hover": [], "color": "#ffb703"}}

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

        t = item["object_type"] if item["object_type"] in types else "DEBRIS"
        types[t]["x"].append(X)
        types[t]["y"].append(Z)
        types[t]["z"].append(Y)
        hover_str = f"<b>{item['name']}</b><br>NORAD ID: #{item['norad_id']}<br>Type: {item['object_type']}<br>Country: {item['country']}<br>Alt: {round(mean_alt, 1)} km<br>Velocity: {item['velocity_km_s']} km/s"
        types[t]["hover"].append(hover_str)

    fig = go.Figure()

    # Add 3D Textured Surface Mesh for Earth Globe
    u_vals = np.linspace(0, 2 * np.pi, 100)
    v_vals = np.linspace(0, np.pi, 50)
    ex = 1.0 * np.outer(np.cos(u_vals), np.sin(v_vals))
    ey = 1.0 * np.outer(np.sin(u_vals), np.sin(v_vals))
    ez = 1.0 * np.outer(np.ones(np.size(u_vals)), np.cos(v_vals))

    fig.add_trace(go.Surface(
        x=ex, y=ey, z=ez,
        colorscale=[[0, '#040b1e'], [0.4, '#0a2356'], [0.7, '#1a4099'], [1, '#e6f2ff']],
        showscale=False,
        name="Earth Globe",
        hoverinfo="none",
        opacity=0.98
    ))

    # Add Point Clouds for Payloads, Debris, and Rocket Bodies
    for t_name, data in types.items():
        if data["x"]:
            fig.add_trace(go.Scatter3d(
                x=data["x"], y=data["y"], z=data["z"],
                mode='markers',
                marker=dict(size=3, color=data["color"], opacity=0.85),
                name=f"{t_name} ({len(data['x'])})",
                text=data["hover"],
                hoverinfo='text'
            ))

    fig.update_layout(
        title=dict(text="<b>OrbitalGuard AI: Plotly 3D Earth & Debris Scatter Globe</b>", font=dict(color="#00e5ff", size=18)),
        paper_bgcolor="#070913",
        plot_bgcolor="#070913",
        scene=dict(
            xaxis=dict(visible=False),
            yaxis=dict(visible=False),
            zaxis=dict(visible=False),
            bgcolor="#070913",
            aspectmode='data'
        ),
        legend=dict(font=dict(color="#f0f4fc"), bgcolor="rgba(14, 18, 36, 0.8)")
    )

    output_html = r"C:\Users\Tarun Vignesh B S\.gemini\antigravity\scratch\space-debris-analytics\plotly_earth_dashboard.html"
    fig.write_html(output_html)
    print(f"Plotly 3D Earth Dashboard saved to: {output_html}")
    fig.show()

if __name__ == "__main__":
    main()
