<script>
  import { onMount } from 'svelte';
  import { fade } from 'svelte/transition';
  import { tweened } from 'svelte/motion';
  import { cubicOut } from 'svelte/easing';

  let isHovered = $state(false);
  let showContent = $state(false);

  // Tweened values for smooth animation
  const width = tweened(200, { duration: 500, easing: cubicOut });
  const height = tweened(44, { duration: 500, easing: cubicOut });
  const br = tweened(10, { duration: 500, easing: cubicOut });
  const glowWidth = tweened(260, { duration: 700, easing: cubicOut });

  $effect(() => {
    if (isHovered) {
      width.set(420);
      height.set(240);
      br.set(20);
      glowWidth.set(500);
      const timer = setTimeout(() => {
        showContent = true;
      }, 300);
      return () => clearTimeout(timer);
    } else {
      width.set(200);
      height.set(44);
      br.set(10);
      glowWidth.set(260);
      showContent = false;
    }
  });

  const monitors = [
    { name: 'Atlassian', status: 'Operational', color: '#27c93f', points: [8, 10, 8, 12, 10, 8, 9, 11, 10, 8, 9, 11] },
    { name: 'Better Stack', status: 'Operational', color: '#27c93f', points: [10, 9, 11, 10, 12, 10, 11, 10, 12, 10, 11, 10] },
    { name: 'API Monitor', status: 'Degraded', color: '#ffbd2e', points: [8, 5, 8, 4, 8, 6, 8, 5, 8, 6, 8, 5] },
    { name: 'Pulse Website', status: 'Operational', color: '#27c93f', points: [10, 11, 10, 12, 10, 11, 12, 11, 10, 11, 12, 11] }
  ];

  function getPath(points) {
    const step = 80 / (points.length - 1);
    return points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${i * step} ${16 - p}`).join(' ');
  }

  const t = 16; // topInset

  // SVG Path for DynamicIslandShape computed from tweened values
  let islandPath = $derived(`
    M 0 0
    Q ${t} 0 ${t} ${t}
    L ${t} ${$height - $br}
    Q ${t} ${$height} ${t + $br} ${$height}
    L ${$width - t - $br} ${$height}
    Q ${$width - t} ${$height} ${$width - t} ${$height - $br}
    L ${$width - t} ${t}
    Q ${$width - t} 0 ${$width} 0
    Z
  `);
</script>

<div 
  class="relative flex justify-center items-start group select-none"
  onmouseenter={() => isHovered = true}
  onmouseleave={() => isHovered = false}
  role="presentation"
>
  <!-- Glow (Behind) -->
  <div 
    class="absolute top-0 left-1/2 -translate-x-1/2 rounded-full bg-red-500/60 blur-[20px] animate-pulse z-0"
    style="width: {$glowWidth}px; height: 44px;"
  ></div>

  <!-- Dynamic Island SVG -->
  <svg 
    width={$width} 
    height={$height} 
    viewBox="0 0 {$width} {$height}"
    class="relative z-10 drop-shadow-2xl"
  >
    <path 
      d={islandPath} 
      fill="black" 
    />
  </svg>

  <!-- Content Overlay -->
  {#if showContent}
    <div 
      in:fade={{ duration: 200 }} 
      class="absolute top-0 left-1/2 -translate-x-1/2 z-20 flex flex-col gap-1 pt-12"
      style="width: {$width - (t * 2)}px"
    >
      {#each monitors as monitor}
        <div class="flex items-center justify-between group/row hover:bg-white/5 rounded-lg py-1.5 px-5 transition-colors cursor-default">
          <div class="flex items-center gap-4">
            <div class="w-2.5 h-2.5 rounded-full shadow-[0_0_10px_currentColor]" style="background-color: {monitor.color}; color: {monitor.color}"></div>
            <div class="flex flex-col">
              <span class="text-[13px] font-mono font-medium text-white/90 leading-none mb-1.5">{monitor.name}</span>
              <span class="text-[10px] font-mono text-white/30 uppercase tracking-widest leading-none">{monitor.status}</span>
            </div>
          </div>
          
          <div class="flex items-center gap-6">
            <div class="flex items-center gap-3">
              <svg width="80" height="16" class="overflow-visible opacity-80">
                <path 
                  d={getPath(monitor.points)} 
                  fill="none" 
                  stroke={monitor.color} 
                  stroke-width="1.5" 
                  stroke-linecap="round" 
                  stroke-linejoin="round"
                />
              </svg>
              <span class="text-[9px] font-mono text-white/20">3h</span>
            </div>
            
            <svg class="w-3 h-3 text-white/30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  svg {
    filter: drop-shadow(0 4px 12px rgba(0,0,0,0.5));
  }
</style>
