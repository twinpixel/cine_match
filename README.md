# CineMatch - AI Movie Recommendation App

CineMatch is a Flutter application that leverages the power of Artificial Intelligence to recommend movies tailored to your individual tastes. This app utilizes extensive interaction with Large Language Models (LLMs) to understand your preferences and suggest films you'll love.

**⚠️ Disclaimer: This software was created for experimental purposes only and should not be considered an example of best practices in software development.**

This project was developed with significant assistance from LLMs, demonstrating the potential of AI in code generation and application development. The author has a foundational understanding of Flutter and Dart.

**You can try a live demo of the application here: [https://twinpixel.github.io/cinematch/](https://twinpixel.github.io/cinematch/)**

## Features

* **AI-Powered Movie Recommendations:** Get personalized movie suggestions based on your preferences, powered by LLMs.
* **Intuitive User Interface:** A user-friendly interface to easily browse and discover new movies.
* **LLM Interaction:** The application heavily relies on interactions with LLMs to understand user tastes and generate recommendations.
* **Poster Downloading Scripts:** Includes Node.js scripts (`listmovies.js` and `download_images.js`) to assist in downloading movie posters. These scripts also utilize LLMs and were written with their assistance.
* **Live Demo Available:** Try the application live in your browser.

## Screenshots

Here are some screenshots of the application:

* **Home Screen:**

    ```markdown
    ![Home Screen](screenshots/screenshot_home.png)
    ```

    <img src="screenshots/screenshot_home.png" alt="Home Screen" width="300">

* **Questions Interface:**

    ```markdown
    ![Questions Interface](screenshots/screenshot_questions.png)
    ```

    <img src="screenshots/screenshot_questions.png" alt="Questions Interface" width="300">

* **Movie Recommendations:**

    ```markdown
    ![Movie Recommendations](screenshots/screenshot_recommendations.png)
    ```

    <img src="screenshots/screenshot_recommendations.png" alt="Movie Recommendations" width="300">

## Missing Configurations

To fully run this application locally, you will need to provide the following configurations:

* **Mistral API Key:** This application interacts with the Mistral LLM. The API key is expected to be set as an environment variable named `KEY_MISTRAL`. Please ensure you have obtained a valid API key from Mistral and have set it in your environment before running the application.
* **Gemini Integration (Vertex AI):** To enable interaction with Google's Gemini API, this application needs to be registered within a Google Cloud account to utilize Vertex AI. Please follow the Google Cloud documentation to set up your project and enable the Vertex AI API. The necessary configuration details for Firebase and Vertex AI integration should then be managed within your Firebase project.

**Without these configurations, the application's functionality that relies on Mistral and Gemini will not work, and the poster downloading scripts might require additional configuration depending on their specific implementation.**

## Node.js Poster Downloading Scripts

This repository includes two Node.js scripts located in the project's root directory:

* **`listmovies.js`:** This script is used for downloading movie posters. It likely interacts with LLMs to identify and retrieve relevant poster images based on movie data.
* **`download_images.js`:** This script also serves the purpose of downloading movie posters. It might have a different approach or functionality compared to `listmovies.js`.

Both of these scripts were written using Large Language Models, further demonstrating the use of AI in this project's development workflow. Please refer to the individual script files for specific usage instructions and any required dependencies. You will need Node.js installed on your system to run these scripts.

## Getting Started (General Flutter Instructions)

1. **Clone the repository:**

    ```bash
    git clone [repository_url]
    ```

2. **Navigate to the project directory:**

    ```bash
    cd cine_match
    ```

3. **Ensure Flutter is installed:** If you don't have Flutter installed, follow the instructions on the official Flutter website: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)

4. **Get the dependencies:**

    ```bash
    flutter pub get
    ```

5. **Provide the missing configurations:**

    * **Mistral API Key:** Set the `KEY_MISTRAL` environment variable in your operating system or development environment.
    * **Gemini (Vertex AI):** Register your application within a Google Cloud account and configure it to use Vertex AI. Ensure your Firebase project is properly linked to your Google Cloud project.

6. **Run the application:**

    ```bash
    flutter run
    ```

## Running the Node.js Scripts

1. **Ensure Node.js and npm are installed:** If you don't have Node.js installed, follow the instructions on the official Node.js website: [https://nodejs.org/](https://nodejs.org/)

2. **Navigate to the project directory in your terminal.**

3. **Install the necessary dependencies for the scripts (if any):** Check the script files for any `require` statements and install the corresponding packages using `npm install [package-name]`.

4. **Run the scripts:**

    ```bash
    node listmovies.js
    node download_images.js
    ```

    Refer to the comments within each script for specific usage instructions and any required input parameters.

**Note:** This application relies on cloud-based AI services and the poster downloading scripts might require specific setup or API keys depending on the services they interact with. Ensure you have the necessary accounts, API keys, and project configurations set up to utilize its full functionality.

## Contributing

Contributions are welcome! If you have suggestions or find issues, please feel free to open an issue or submit a pull request.

## Author

This application was developed by an author with rudimentary knowledge of Flutter and Dart, with significant assistance from Large Language Models.
