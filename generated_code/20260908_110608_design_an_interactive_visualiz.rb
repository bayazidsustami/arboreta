require 'optparse'
require 'open3'

# ==============================================================================
# Git History Fractal Forest Visualizer
# Parses local git history and builds an interactive HTML/Canvas visualizer 
# depicting branches/merges as growing fractal structures with churn foliage.
# ==============================================================================

class GitFractalVisualizer
  # Colors for foliage mapping based on file churn (insertions + deletions)
  SEASONAL_PALETTES = {
    spring: ['#88CE02', '#228B22', '#32CD32', '#006400'], # Low churn
    summer: ['#FFD700', '#FF8C00', '#FFA500', '#DAA520'], # Medium churn
    autumn: ['#FF4500', '#B22222', '#D2691E', '#CD5C5C'], # High churn
    winter: ['#E0EEEE', '#B0C4DE', '#87CEEB', '#4682B4']  # Refactoring / Deletions
  }.freeze

  def initialize(path = '.', limit = 200)
    @repo_path = path
    @limit = limit
    @commits = []
    @branches = {}
  end

  # Parse git log using open3 to extract commit relationships and churn statistics
  def parse_git_log
    cmd = "git log --max-count=#{@limit} --pretty=format:'COMMIT|%H|%P|%an|%at|%s' --numstat"
    stdout, stderr, status = Open3.capture3(cmd, chdir: @repo_path)

    unless status.success?
      puts "Error parsing git repository at '#{@repo_path}': #{stderr}"
      exit 1
    end

    current_commit = nil

    stdout.each_line do |line|
      line = line.strip
      next if line.empty?

      if line.start_with?('COMMIT|')
        _, hash, parents, author, time, subject = line.split('|', 6)
        parent_hashes = parents.to_s.split(' ')
        
        current_commit = {
          hash: hash,
          parents: parent_hashes,
          author: author,
          timestamp: time.to_i,
          subject: subject,
          insertions: 0,
          deletions: 0,
          files_changed: 0,
          is_merge: parent_hashes.length > 1
        }
        @commits << current_commit
      elsif current_commit
        parts = line.split(/\s+/)
        if parts.length >= 3
          add = parts[0] == '-' ? 0 : parts[0].to_i
          del = parts[1] == '-' ? 0 : parts[1].to_i
          current_commit[:insertions] += add
          current_commit[:deletions] += del
          current_commit[:files_changed] += 1
        end
      end
    end

    @commits.reverse! # Chronological order
  end

  # Generate standalone HTML containing Canvas 2D render loop and JS controls
  def generate_html_output
    json_data = @commits.to_json

    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <title>Git History Fractal Forest</title>
          <style>
              body, html {
                  margin: 0; padding: 0; width: 100%; height: 100%;
                  overflow: hidden; background-color: #0b0d12;
                  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                  color: #e0e0e0;
              }
              #canvas { width: 100vw; height: 100vh; display: block; }
              #ui {
                  position: absolute; top: 20px; left: 20px;
                  background: rgba(15, 18, 25, 0.85); backdrop-filter: blur(8px);
                  padding: 15px 20px; border-radius: 8px; border: 1px solid #2a2f3a;
                  box-shadow: 0 4px 20px rgba(0,0,0,0.5); pointer-events: none;
              }
              h1 { margin: 0 0 5px 0; font-size: 1.2rem; color: #64ffda; }
              p { margin: 2px 0; font-size: 0.85rem; color: #a0a5b5; }
              #controls {
                  position: absolute; bottom: 20px; left: 50%;
                  transform: translateX(-50%); background: rgba(15, 18, 25, 0.85);
                  backdrop-filter: blur(8px); padding: 10px 25px; border-radius: 30px;
                  border: 1px solid #2a2f3a; display: flex; gap: 15px; align-items: center;
              }
              button {
                  background: #64ffda; border: none; color: #0a192f;
                  padding: 8px 16px; border-radius: 20px; font-weight: bold;
                  cursor: pointer; transition: all 0.2s ease;
              }
              button:hover { background: #4cdb force; transform: scale(1.05); }
              input[type=range] { accent-color: #64ffda; cursor: pointer; }
          </style>
      </head>
      <body>
          <div id="ui">
              <h1>Git Fractal Forest</h1>
              <p id="info-commit">Parsing commits...</p>
              <p id="info-stats">Total Commits: #{commits.length}</p>
          </div>
          <div id="controls">
              <button id="btn-play">Pause</button>
              <input type="range" id="slider" min="0" max="#{commits.length - 1}" value="0" style="width: 300px;">
              <button id="btn-reset">Reset View</button>
          </div>
          <canvas id="canvas"></canvas>

          <script>
              const commits = #{json_data};
              const canvas = document.getElementById('canvas');
              const ctx = canvas.getContext('2d');

              let width, height;
              function resize() {
                  width = canvas.width = window.innerWidth;
                  height = canvas.height = window.innerHeight;
              }
              window.addEventListener('resize', resize);
              resize();

              // Interactive State
              let currentIndex = 0;
              let isPlaying = true;
              let animProgress = 1.0;
              let zoom = 1, panX = 0, panY = 0;
              let isDragging = false, startX, startY;

              // Pan/Zoom Controls
              canvas.addEventListener('mousedown', e => { isDragging = true; startX = e.clientX - panX; startY = e.clientY - panY; });
              canvas.addEventListener('mousemove', e => { if(isDragging) { panX = e.clientX - startX; panY = e.clientY - startY; } });
              canvas.addEventListener('mouseup', () => isDragging = false);
              canvas.addEventListener('wheel', e => {
                  const zoomFactor = e.deltaY < 0 ? 1.1 : 0.9;
                  zoom *= zoomFactor;
              });

              document.getElementById('btn-reset').onclick = () => { zoom = 1; panX = 0; panY = 0; };
              document.getElementById('btn-play').onclick = (e) => {
                  isPlaying = !isPlaying;
                  e.target.innerText = isPlaying ? "Pause" : "Play";
              };
              const slider = document.getElementById('slider');
              slider.oninput = (e) => {
                  currentIndex = parseInt(e.target.value);
                  animProgress = 1.0;
              };

              // Map commits into structural fractal trees
              function buildTrees() {
                  let nodes = {};
                  let roots = [];

                  commits.slice(0, currentIndex + 1).forEach((c, idx) => {
                      let node = {
                          hash: c.hash,
                          subject: c.subject,
                          author: c.author,
                          churn: c.insertions + c.deletions,
                          isMerge: c.is_merge,
                          children: [],
                          depth: 0,
                          x: 0, y: 0, angle: 0
                      };
                      nodes[c.hash] = node;

                      let parentHash = c.parents[0];
                      if (parentHash && nodes[parentHash]) {
                          nodes[parentHash].children.push(node);
                      } else {
                          roots.push(node);
                      }
                  });
                  return { nodes, roots };
              }

              function getFoliageColor(churn) {
                  if (churn < 10) return '#88CE02';
                  if (churn < 50) return '#FFD700';
                  if (churn < 200) return '#FF4500';
                  return '#87CEEB';
              }

              // Recursive Render Function for Branches & Grafted Roots
              function drawBranch(node, x, y, length, angle, depth) {
                  ctx.save();
                  ctx.translate(x, y);
                  ctx.rotate(angle);

                  let branchWidth = Math.max(1, 10 - depth * 1.2);
                  ctx.lineWidth = branchWidth;
                  ctx.strokeStyle = node.isMerge ? '#a855f7' : '#5c3a21'; // Merges show as grafted purple branches

                  ctx.beginPath();
                  ctx.moveTo(0, 0);
                  let targetY = -length;
                  ctx.lineTo(0, targetY);
                  ctx.stroke();

                  let nextX = 0;
                  let nextY = targetY;

                  // Foliage rendering based on code churn
                  if (node.children.length === 0 || depth > 6) {
                      let leafRadius = Math.min(15, Math.max(3, Math.sqrt(node.churn) * 0.8));
                      ctx.beginPath();
                      ctx.arc(nextX, nextY, leafRadius, 0, Math.PI * 2);
                      ctx.fillStyle = getFoliageColor(node.churn);
                      ctx.globalAlpha = 0.7;
                      ctx.fill();
                      ctx.globalAlpha = 1.0;
                  }

                  let childCount = node.children.length;
                  node.children.forEach((child, i) => {
                      let spread = 0.5;
                      let childAngle = childCount === 1 ? (Math.random()*0.2 - 0.1) : (-spread/2 + (spread / (childCount - 1 || 1)) * i);
                      let childLength = length * (0.75 + Math.random() * 0.1);
                      drawBranch(child, nextX, nextY, childLength, childAngle, depth + 1);
                  });

                  ctx.restore();
              }

              function render() {
                  ctx.clearRect(0, 0, width, height);
                  ctx.save();
                  ctx.translate(width / 2 + panX, height * 0.85 + panY);
                  ctx.scale(zoom, zoom);

                  let { roots } = buildTrees();
                  let treeSpacing = 200;
                  let startX = -((roots.length - 1) * treeSpacing) / 2;

                  roots.forEach((root, idx) => {
                      drawBranch(root, startX + idx * treeSpacing, 0, 70, 0, 0);
                  });

                  ctx.restore();

                  // Update UI Frame
                  if (commits[currentIndex]) {
                      let c = commits[currentIndex];
                      document.getElementById('info-commit').innerText = `[${c.hash.substring(0,7)}] ${c.subject}`;
                      document.getElementById('info-stats').innerText = `Author: ${c.author} | +${c.insertions} -${c.deletions}`;
                      slider.value = currentIndex;
                  }

                  if (isPlaying) {
                      animProgress += 0.05;
                      if (animProgress >= 1.0) {
                          animProgress = 0;
                          if (currentIndex < commits.length - 1) {
                              currentIndex++;
                          } else {
                              isPlaying = false;
                              document.getElementById('btn-play').innerText = "Replay";
                          }
                      }
                  }

                  requestAnimationFrame(render);
              }

              render();
          </script>
      </body>
      </html>
    HTML
  end

  def run(output_file = 'git_fractal_forest.html')
    puts "Parsing Git history..."
    parse_git_log
    puts "Generating Fractal Forest HTML visualization..."
    html = generate_html_output
    File.write(output_file, html)
    puts "Successfully generated #{output_file} with #{@commits.length} commits!"
    puts "Open the file in your browser to view the interactive visualizer."
  end
end

# Executable block
options = { limit: 150, output: 'git_fractal_forest.html', path: '.' }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby git_fractal.rb [options]"
  opts.on("-n", "--limit LIMIT", Integer, "Number of commits to parse (default 150)") { |v| options[:limit] = v }
  opts.on("-o", "--output FILE", String, "Output HTML file name") { |v| options[:output] = v }
  opts.on("-p", "--path PATH", String, "Target Git repository path") { |v| options[:path] = v }
end.parse!

visualizer = GitFractalVisualizer.new(options[:path], options[:limit])
visualizer.run(options[:output])