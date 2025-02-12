const express = require('express');
const nodemailer = require('nodemailer');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Create a transporter using SMTP
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'rakshitkaushal1528@gmail.com',
    pass: 'yftqplxcwhnlbtes'  // Use App Password, not regular password
  }
});

// OTP Generation Function
function generateOTP() {
  return Math.floor(10000 + Math.random() * 90000).toString();
}

// Endpoint to send OTP
app.post('/send-otp', async (req, res) => {
  const { email } = req.body;
  const otp = generateOTP();

  const mailOptions = {
    from: 'rakshitkaushal1528@gmail.com',
    to: email,
    subject: 'AIMS Portal OTP',
    text: `Your OTP for AIMS Portal is ${otp}. It is valid for 5 minutes.`
  };

  try {
    await transporter.sendMail(mailOptions);
    res.json({ success: true, otp });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});