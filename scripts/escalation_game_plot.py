import numpy as np
import matplotlib.pyplot as plt

# Constants
oi_fee_yearly = 0.5
weeks_per_year = 52
t_max = 7  # in weeks
fork_threshold = 275_000
smois = [0, 1000, 10_000, 100_000, 1_000_000]
I_0 = 0.4
k = 5
alpha = 2.0  # alpha multiplier for burn in investment(t), adjust if needed

# Convert yearly fee to weekly
oi_fee = oi_fee_yearly / weeks_per_year

# Time vector
t = np.linspace(0.01, t_max, 300)

def burn(t, smoi, oi_fee, fork_threshold, I_0, k, t_max):
	# B is burn(t_max) for use in the max term
	B = smoi * (1 - np.exp(-oi_fee * t_max))
	
	# Burn term 1
	burn_term1 = smoi * (1 - np.exp(-oi_fee * t))
	
	# Burn term 2
	burn_term2 = 0.2 * (
		I_0 + (fork_threshold + max(B, 0.25 * fork_threshold) - I_0) * (t / t_max) ** k
	)
	
	return np.maximum(burn_term1, burn_term2)

def investment(t, burn_t, fork_threshold, I_0, k, t_max, alpha):
	# B is max burn at t_max
	B = max(burn_t[-1], 0.25 * fork_threshold)
	
	invest_term = I_0 + (fork_threshold + B - I_0) * (t / t_max) ** k
	return np.maximum.reduce([
		np.full_like(t, I_0),
		alpha * burn_t,
		invest_term
	])

def profit(inv_t, burn_t):
	return (2 * inv_t - burn_t - inv_t) / inv_t

# Plotting
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(10, 12))

for smoi in smois:
	burn_vals = burn(t, smoi, oi_fee, fork_threshold, I_0, k, t_max)
	inv = investment(t, burn_vals, fork_threshold, I_0, k, t_max, alpha)
	brn = 0.2 * inv  # Since burn(t) uses 0.2 * investment in second term, this approximates burn proportionally
	prf = profit(inv, brn)

	ax1.plot(t, inv, label=f'SMOI={smoi}')
	ax2.plot(t, burn_vals, label=f'SMOI={smoi}')
	ax3.plot(t, prf, label=f'SMOI={smoi}')

ax1.set_title('Investment over Time')
ax1.set_xlabel('Weeks')
ax1.set_ylabel('Investment')
ax1.legend()
ax1.grid(True)

ax2.set_title('Burn over Time')
ax2.set_xlabel('Weeks')
ax2.set_ylabel('Burn')
ax2.legend()
ax2.grid(True)

ax3.set_title('Profit over Time')
ax3.set_xlabel('Weeks')
ax3.set_ylabel('Profit')
ax3.legend()
ax3.grid(True)

plt.tight_layout()
plt.show()
