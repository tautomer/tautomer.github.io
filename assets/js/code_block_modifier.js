document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('div.highlight').forEach(function (highlightBlock) {
        const preBlock = highlightBlock.querySelector('pre');

        // Create a new header div
        const header = document.createElement('div');
        header.classList.add('code-header');

        // Create a container for buttons
        const buttonContainer = document.createElement('div');
        buttonContainer.classList.add('code-buttons');

        // Always create and add the Copy button
        const copyButton = document.createElement('button');
        copyButton.classList.add('copy-code-button');
        copyButton.innerHTML = '<i class="fa-solid fa-copy"></i> Copy';

        copyButton.addEventListener('click', function () {
            const code = preBlock.textContent;
            navigator.clipboard.writeText(code).then(() => {
                copyButton.innerHTML = '<i class="fa-solid fa-check"></i> Copied!';
                setTimeout(() => {
                    copyButton.innerHTML = '<i class="fa-solid fa-copy"></i> Copy';
                }, 2000);
            });
        });

        // Check for overflow and conditionally add the Expand button
        const isOverflowing = preBlock.scrollHeight > preBlock.clientHeight;
        if (isOverflowing) {
            const expandButton = document.createElement('button');
            expandButton.classList.add('expand-code-button');
            expandButton.innerHTML = '<i class="fa-solid fa-square-caret-down"></i> Expand';

            expandButton.addEventListener('click', function () {
                preBlock.classList.toggle('expanded');
                if (preBlock.classList.contains('expanded')) {
                    expandButton.innerHTML = '<i class="fa-solid fa-square-caret-up"></i> Collapse';
                } else {
                    expandButton.innerHTML = '<i class="fa-solid fa-square-caret-down"></i> Expand';
                }
            });
            buttonContainer.appendChild(expandButton);
        }

        // Append the Copy button and the full button container
        buttonContainer.appendChild(copyButton);
        header.appendChild(buttonContainer);

        // Insert the header at the top of the highlight block
        highlightBlock.insertBefore(header, highlightBlock.firstChild);
    });
});